# Current Code Review: Simple Financial API

Дата ревью: 2026-05-25

Контекст: тестовое задание на вакансию Ruby developer в EPAM. Фокус ревью - слабые места реализации, риски финансового API и пробелы в тестах.

## Проверка

Тесты запускались в Docker:

```bash
docker exec api-rails bundle exec rspec --format progress
```

Результат:

```text
112 examples, 0 failures
Finished in 2.31 seconds
Randomized with seed 9096
```

Прошедшие тесты подтверждают happy path и часть конкурентных сценариев для `deposit`, `withdraw` и `transfer`, но не покрывают несколько критичных financial-grade сценариев.

## Краткий вывод

Проект показывает рабочее владение Rails API, Devise JWT, PostgreSQL row locks, сервисными объектами и request/service specs. Основа выглядит лучше типичного тестового задания: есть Docker, единый JSON envelope, аутентификация, rate limiting, транзакции и блокировки.

Основные слабые места находятся не в базовой Rails-структуре, а в требованиях, которые важны именно для финансовой системы: идемпотентность операций, строгая модель денег, конкурентный reverse, авторизация отката операций и инварианты на уровне базы данных.

## Сильные стороны

- Сервисный слой для финансовых операций: `AccountOperations::DepositService`, `WithdrawService`, `TransferService`, `ReverseService`.
- Используются транзакции и row locks для операций с балансом.
- В `TransferService` счета лочатся в стабильном порядке по `id`, что снижает риск deadlock при переводах A <-> B.
- Есть request specs и service specs, включая concurrent specs для deposit/transfer.
- Подключены Devise JWT, Rack CORS и Rack Attack.
- API возвращает единый response envelope `{ status, data }`.
- Поддержана выборка счета по `account_number`, `account_id` и `currency`.

## Findings

### Critical: concurrent double reverse

Файл: `app/services/account_operations/reverse_service.rb`

В `ReverseService#call` проверка `transaction.status_completed?` выполняется до блокировки счетов:

```ruby
def call
  validate!

  ActiveRecord::Base.transaction do
    reverse_transfer!
  end
end
```

Проблема: сама исходная `transaction` не блокируется. Два параллельных запроса reverse могут оба пройти `validate!`, оба создать reversal transaction и оба переложить деньги обратно.

Последствие: один перевод может быть отменен дважды.

Рекомендация:

- Обернуть исходную транзакцию в `transaction.with_lock`.
- Повторно проверять `status_completed?` внутри lock.
- Добавить связь reversal -> original transaction и уникальный индекс, запрещающий больше одного reversal для одной исходной операции.

### High: recipient can reverse incoming transfer

Файл: `app/controllers/api/v1/transactions_controller.rb`

Транзакция ищется через ledger текущего счета:

```ruby
@transaction = @account.ledger_entries.find(params[:id])
```

`ledger_entries` включает операции, где счет является и source, и target. Поэтому получатель перевода видит входящий transfer в своем ledger и может вызвать:

```http
POST /api/v1/accounts/:account_id/transactions/:id/reverse
```

Проблема: бизнес-право на reverse не отделено от права просмотра ledger entry.

Последствие: получатель может откатить входящий перевод без отдельного разрешения.

Рекомендация:

- Разрешать reverse только инициатору перевода, администратору или отдельной роли.
- Явно зафиксировать бизнес-правило в тестах.
- В контроллере не полагаться только на принадлежность transaction к ledger.

### High: inconsistent money scale

Файлы:

- `app/controllers/concerns/amount_validatable.rb`
- `db/schema.rb`

`parse_amount!` принимает любой `BigDecimal > 0`:

```ruby
amount = BigDecimal(value.to_s)
raise Account::InvalidAmountError, "Amount must be positive" if amount <= 0
```

При этом:

- `accounts.balance` хранится как `decimal(10,2)`;
- `transactions.amount` хранится как `decimal(19,4)`.

Проблема: запрос с суммой вроде `10.9999` может попасть в transaction с 4 знаками, а balance будет округлен/обрезан до 2 знаков на уровне базы.

Последствие: ledger и фактический баланс могут расходиться.

Рекомендация:

- Ограничить scale суммы по валюте, например максимум 2 знака для USD/EUR.
- Использовать одинаковую точность для balance и transaction amount или хранить суммы в minor units (`integer` cents).
- Добавить request/service specs на `10.999`, `0.001`, строковые и экспоненциальные значения.

### High: no idempotency for financial POST operations

Файл: `docs/api.md`

В документации прямо указано:

```text
Planned (not implemented)
- Idempotency-Key header for financial POST operations
```

Проблема: `deposit`, `withdraw`, `transfer`, `reverse` не идемпотентны.

Последствие: если клиент повторит запрос после timeout/network retry, операция выполнится повторно.

Рекомендация:

- Ввести `Idempotency-Key` для всех financial POST endpoints.
- Хранить результат операции по ключу, пользователю и endpoint/action.
- Возвращать тот же результат при повторе идентичного запроса.
- Отказывать при повторе ключа с другим body.

### Medium: read endpoint creates account

Файлы:

- `app/services/account_resolver.rb`
- `app/models/user.rb`

Если счет явно не выбран, `AccountResolver` вызывает `user.default_account`, а `default_account` делает:

```ruby
accounts.find_or_create_by(currency: "USD") do |account|
  account.status = "active"
end
```

Проблема: GET-like операции, например balance, могут создавать USD-счет.

Последствие: read endpoint имеет side effect, что усложняет аудит, кеширование и reasoning об API.

Рекомендация:

- Создавать default account при регистрации пользователя.
- Или требовать явного `POST /accounts`.
- Для read endpoints использовать только `find_by!`, без `create`.

### Medium: account creation race is not handled cleanly

Файлы:

- `app/models/user.rb`
- `app/models/account.rb`

Есть unique indexes на `account_number` и `[user_id, currency]`, но приложение не обрабатывает `ActiveRecord::RecordNotUnique` как доменную ошибку.

Риски:

- Два параллельных запроса могут одновременно создать default account.
- `generate_account_number` проверяет уникальность через `exists?`, но это не атомарно.

Последствие: пользователь может получить 500 вместо аккуратного API-ответа или retry.

Рекомендация:

- Добавить retry на collision `account_number`.
- Для default account использовать `create_or_find_by` или обработку unique violation.
- Добавить concurrent spec на создание default account.

### Medium: important invariants are missing at database level

Файл: `db/schema.rb`

Сейчас часть правил живет только в Rails validations/services. Для финансовой системы этого мало.

Не хватает DB constraints:

- `transactions.status` и `transactions.transaction_type` должны быть `null: false`.
- `transactions.amount > 0`.
- `accounts.balance >= 0`.
- `accounts.currency IN ('USD', 'EUR')`.
- `accounts.status IN ('active', 'on_hold', 'closed')`.
- Правила source/target по типу transaction: deposit должен иметь target, withdrawal должен иметь source, transfer должен иметь оба.

Последствие: баг, console script или будущий bulk import может записать невозможное состояние.

Рекомендация:

- Добавить check constraints и `null: false`.
- Оставить Rails validations для UX, но критичные инварианты дублировать в БД.

### Low: domain naming and API copy need polish

Файлы:

- `app/models/account.rb`
- `app/controllers/api/v1/accounts_controller.rb`

Статус счёта: **`on_hold`** (миграция с `holded`). Сообщения API:

```text
Account placed on hold successfully.
Account activated successfully.
```

## Пробелы в тестах

Стоит добавить specs на сценарии:

- Два параллельных `reverse` одного transfer.
- Попытка reverse от имени получателя входящего перевода.
- Повтор financial POST с одним и тем же `Idempotency-Key`.
- Amount с большим scale: `10.999`, `0.001`.
- Concurrent creation default USD account.
- Поведение при `ActiveRecord::RecordNotUnique` на account number.
- DB constraints на невозможные transaction/account states.

## Приоритет исправлений

1. Защитить `ReverseService` от double reverse через `transaction.with_lock` и DB-level uniqueness.
2. Явно ограничить, кто имеет право делать reverse.
3. Нормализовать модель денег: scale validation или integer minor units.
4. Добавить idempotency для `deposit`, `withdraw`, `transfer`, `reverse`.
5. Убрать side effect из read paths, особенно default account creation при balance.
6. Добавить DB constraints для финансовых инвариантов.
7. Дополнить тесты указанными edge cases.
