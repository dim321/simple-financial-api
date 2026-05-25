# Code review: Simple Financial API

Ревью тестового задания на вакансию Ruby developer. Фокус — слабые места реализации.

**Связанный документ:** [План исправлений](./review-fix-plan.md)

---

## Краткий вывод

Задание показывает знакомство с Rails 8, Devise JWT, PostgreSQL locks и сервисными объектами. Для production-ready финансового API не хватает согласованности API с доменом (currency), корректной конкурентности на transfer, целостности ledger, завершённости routes и выравнивания CI с тестами.

---

## Плюсы

- Сервисный слой для операций (`AccountOperations::*`)
- `with_lock` на deposit/withdraw/transfer
- RSpec-покрытие happy path и части edge cases
- Docker / Kamal, CI с Brakeman и RuboCop
- Понятный JSON envelope `{ status, data }`

---

## Критичные проблемы

### 1. Race condition при переводе: проверка баланса вне блокировки

В `TransferService` валидация выполняется **до** `with_lock`:

```ruby
# app/services/account_operations/transfer_service.rb
def validate!
  # ...
  raise Account::InsufficientFundsError, 'Insufficient funds' if source_account.balance < amount
end

def perform_transfer
  source_account.with_lock do
    target_account.with_lock do
      source_account.update!(balance: source_account.balance - amount)
```

Два параллельных запроса могут оба пройти `validate!` при балансе 100 и сумме 80. Внутри lock повторной проверки нет — возможен отрицательный баланс (частично спасает только `validates :balance, numericality: { greater_than_or_equal_to: 0 }` на модели, но это `RecordInvalid`, а не `InsufficientFundsError`).

Тест на concurrency есть, но он не покрывает сценарий «две большие суммы одновременно».

### 2. Параметр `currency` в API фактически не используется

В README и тестах передаётся `currency: 'USD'`, но контроллер всегда берёт `default_account` (USD):

```ruby
# app/controllers/api/v1/accounts_controller.rb
def set_account
  @account = if params[:id]
    current_user.accounts.find(params[:id])
  else
    current_user.default_account
  end
end
```

`deposit` / `withdraw` / `transfer` / `balance` игнорируют валюту. При нескольких счетах в разных валютах API ведёт себя непредсказуемо. В `balance` есть TODO, но поведение не реализовано.

### 3. Переопределение ассоциации `transactions` в `Account`

```ruby
# app/models/account.rb
has_many :transactions, dependent: :restrict_with_error
# ...
def transactions
  Transaction.for_account(self).recent
end
```

Метод перекрывает `has_many`. Ломаются стандартные вызовы ActiveRecord (`account.transactions.create!`, `build`, `<<`). `User` объявляет `has_many :transactions, through: :accounts` — через такую «ассоциацию» это тоже работает некорректно.

### 4. Маршруты без реализации

В `routes.rb` есть `resources :accounts, only: [:index, ...]` и вложенные `transactions` с `post :reverse`, но:

- нет `index` в `AccountsController`;
- нет `TransactionsController`;
- нет `reverse`.

Это «мёртвые» эндпоинты — при обращении получите ошибку маршрутизации или abstract action.

### 5. CI не запускает RSpec

В `.github/workflows/ci.yml`:

```yaml
run: bin/rails db:test:prepare test
```

Запускается Minitest (`test/models/user_test.rb` — один файл), а основной набор — **79 RSpec examples** из README. Регрессии в финансовой логике CI может не поймать.

---

## Архитектура и доменная модель

### Двойная запись переводов

`Transaction.create_transfer!` создаёт **две** записи типа `transfer`, вторая с отрицательной суммой и перепутанными source/target:

```ruby
# app/models/transaction.rb
create!(
  source_account: source_account,
  target_account: target_account,
  amount: amount,
  # ...
)
create!(
  source_account: target_account,
  target_account: source_account,
  amount: -amount,
  # ...
)
```

Для ledger это нестандартно: дублирование, риск рассинхрона, сложнее отчёты и reversal. Обычно одна транзакция или double-entry с явными debit/credit.

### Статусы транзакций не используются по смыслу

Есть enum `pending`, `completed`, `failed`, `reversed`, но все операции сразу `completed`. `reverse` в routes не реализован — модель обещает больше, чем даёт API.

### Несогласованность валют по умолчанию

| Место | Значение |
|--------|----------|
| `schema` / `default_account` | USD |
| `Account#set_default_currency` | RUB |
| README / примеры | USD |

При создании счёта без `currency` в params может получиться RUB, тогда как остальной код ориентирован на USD.

### `find_or_create_by!` без явной инициализации

```ruby
# app/models/user.rb
def account_in_currency(currency)
  accounts.find_or_create_by!(currency: currency)
end
```

Счёт может создаться неявно в hot path операций — лучше явный сервис создания счёта.

---

## API и контроллеры

### Дублирование аутентификации

- Devise + devise-jwt (`dispatch`/`revocation` на sign_in/sign_out);
- плюс свой `authenticate_user_from_token!` в `ApplicationController` с ручным `JWT.decode`.

Два пути аутентификации усложняют поддержку. Logout в `SessionsController#respond_to_on_destroy` вручную декодирует JWT и **не вызывает** стандартный `sign_out` / revocation flow Devise — отзыв токена через JTIMatcher может не сработать.

### Слабая валидация входных данных

- `params[:amount].to_d` — `nil` → `0.0`, пустая строка → `0` (тихий нулевой депозит вместо 422);
- нет strong params / schema для amount, recipient_email;
- нет лимитов на сумму, формат денег.

### Утечка информации при transfer

`set_recipient_account` ищет по email и всегда берёт `default_account` получателя, **не** счёт в валюте из запроса. Сообщение «Target account unknown» не различает «нет пользователя» и «нет счёта в валюте» — возможен user enumeration.

### Дублирование `rescue_from ActiveRecord::RecordNotFound`

И в `AuthenticationErrors`, и в `AccountErrors` — последний подключённый concern «побеждает»; поведение 404 зависит от порядка include.

### Мёртвый код в исключениях

`TargetAccountInactiveError`, `SameAccountError` объявлены, но не выбрасываются (используются `InactiveAccountError` и `SelfTransferError`).

---

## Безопасность

| Риск | Комментарий |
|------|-------------|
| CORS `origins '*'` | Допустимо для demo, в production — whitelist |
| Email в JSON счёта | Лишняя PII в `AccountSerializer` |
| Нет rate limiting | Brute force sign_in, спам transfer |
| Нет idempotency | Повтор POST = повторная операция |
| Слабые требования к паролю | min 6 символов |
| `User#jwt_token` | Публичный метод генерации токена вне Devise flow |

---

## Качество кода и стиль

**Плюсы:** вынос операций в `AccountOperations::*`, блокировки в deposit/withdraw, понятные custom errors, JSON envelope `{ status, data }`.

**Минусы:**

- повторяющиеся `rescue_from` в `AccountErrors` (DRY);
- `Account#transfer` возвращает только `source_account`, теряя `target` из сервиса;
- вложенные транзакции: `with_lock` + `ActiveRecord::Base.transaction` внутри — избыточно, но не критично;
- deadlock risk при transfer: порядок lock `source` → `target` не сортирован по `id` (классическая рекомендация для переводов A↔B);
- serializer: `serializable_hash[:data][:attributes]` — хрупко, лучше обёртка или Alba/Blueprint;
- ~~опечатка `holded`~~ → исправлено на `on_hold`;
- README: опечатки, двойной слэш в URL, требование `master.key` у ревьюера.

---

## Тестирование

**Сильные стороны:** service specs (deposit, withdraw, transfer), request specs, integration `financial_flow_spec`, concurrent transfer test.

**Пробелы:**

- нет request-тестов на неверный `currency`, `amount: null`, отсутствие `index`/`transactions`;
- нет теста logout + повторное использование токена;
- нет тестов на закрытый/hold счёт через API;
- CI не гоняет RSpec;
- Minitest почти пустой — дублирование фреймворков без пользы.

---

## Рекомендации по приоритету

1. Перенести `InsufficientFunds` и валидации баланса **внутрь** `with_lock` (или `UPDATE ... WHERE balance >= amount`).
2. Пробросить `currency` / `account_number` во все операции и в `balance`.
3. Убрать override `Account#transactions`, заменить на `scope` / отдельное имя (`ledger_entries`).
4. Реализовать или удалить routes (`index`, `transactions`, `reverse`).
5. В CI: `bundle exec rspec` вместо/вместе с пустым Minitest.
6. Упростить auth: один путь через Devise/Warden или явный сервис JWT + revocation на logout.
7. Единая модель транзакций (одна запись на transfer) и использование статусов, если они в схеме.

---

## Матрица замечаний → план исправлений

| Замечание | Фаза в [review-fix-plan.md](./review-fix-plan.md) |
|-----------|---------------------------------------------------|
| Race condition transfer | 1.1 |
| Race condition withdraw | 1.2 |
| `currency` не используется | 1.3 |
| Override `Account#transactions` | 2.1 |
| Две записи на transfer | 2.2 |
| RUB vs USD default | 2.3 |
| Мёртвые routes | 3.1 |
| `amount.to_d` → 0 | 3.2 |
| DRY / мёртвые exceptions | 3.3 |
| Двойная аутентификация | 4.1 |
| Logout не отзывает JWT | 4.1 |
| CORS `*` | 5.1 |
| Email в serializer | 5.2 |
| Нет rate limit / idempotency | 5.3, 5.4 |
| CI не гоняет RSpec | 6.1 |
| Пробелы в тестах | 6.2 |
| README / опечатки | 6.3 |
| serializer boilerplate | 7 |
