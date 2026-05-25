# Current Review Fix Plan

Дата: 2026-05-25

Основание: [current-code-review.md](./current-code-review.md)

Цель: устранить слабые места текущей реализации Simple Financial API без переписывания проекта с нуля. План расставлен по приоритету риска: сначала корректность финансовых операций и безопасность, затем устойчивость данных и полировка API.

## Definition of Done

- `docker exec api-rails bundle exec rspec` проходит без failures.
- Добавлены regression specs на каждый исправленный finding.
- Финансовые POST-операции защищены от повторного выполнения при retry клиента.
- Один transfer нельзя отменить дважды, включая concurrent reverse.
- Получатель входящего transfer не может самовольно выполнить reverse.
- Суммы принимаются только в допустимом формате для поддерживаемых валют.
- База данных защищает критичные инварианты: positive amounts, non-negative balances, required transaction status/type.
- Документация API синхронизирована с фактическим поведением.

## Phase 0. Safety Net

Оценка: 2-3 часа

Задача: сначала зафиксировать текущие баги падающими тестами, чтобы каждое исправление было доказуемым.

### 0.1 Concurrent double reverse spec

Файлы:

- `spec/services/account_operations/reverse_service_spec.rb`
- или расширить `spec/requests/api/v1/transactions_spec.rb`

Сценарий:

- Создать transfer на 100.
- Запустить два parallel reverse одного `Transaction`.
- Ожидание: только один reverse успешен, второй получает `NotReversibleError` или API `422`.
- `Transaction.count` увеличивается только на 1 reversal entry.
- Балансы возвращены ровно один раз.

### 0.2 Reverse authorization spec

Файл:

- `spec/requests/api/v1/transactions_spec.rb`

Сценарий:

- Sender переводит деньги recipient.
- Recipient вызывает reverse через свой `recipient_account.id`.
- Ожидание: `403 Forbidden` или `404 Not Found`, но не успешный reverse.
- Балансы не меняются.

Рекомендация: использовать `403`, если API явно сообщает о запрете. Использовать `404`, если нужно скрыть существование операции.

### 0.3 Money scale specs

Файлы:

- `spec/requests/api/v1/accounts_spec.rb`
- `spec/services/account_operations/*_service_spec.rb`

Сценарии:

- `amount: "10.99"` принимается.
- `amount: "10.999"` отклоняется.
- `amount: "0.001"` отклоняется.
- `amount: "1e2"` либо явно принимается как `100.00`, либо отклоняется - выбрать и зафиксировать.
- `amount: "abc"`, `nil`, `""` отклоняются.

### 0.4 Idempotency specs

Файл:

- `spec/requests/api/v1/accounts_spec.rb`

Сценарии:

- Повтор `POST /deposit` с тем же `Idempotency-Key` и тем же body возвращает тот же результат и не меняет баланс второй раз.
- Повтор того же key с другим body возвращает конфликт `409`.
- Без `Idempotency-Key` поведение остается текущим или endpoint требует key - выбрать контракт в Phase 3.

## Phase 1. Reverse Correctness And Authorization

Оценка: 4-6 часов

Зависимости: Phase 0.1, 0.2

### 1.1 Lock original transaction during reverse

Файл:

- `app/services/account_operations/reverse_service.rb`

Изменения:

- Перенести `validate!` внутрь транзакции и `transaction.with_lock`.
- После lock повторно проверить `transaction_type_transfer?` и `status_completed?`.
- Лочить accounts после lock исходной transaction.
- Сохранять порядок account locks по `id`, как сейчас.

Целевой контур:

```ruby
def call
  ActiveRecord::Base.transaction do
    transaction.with_lock do
      validate!
      reverse_transfer!
    end
  end

  transaction.reload
end
```

Важно: внутри `reverse_transfer!` не использовать stale status исходной транзакции.

### 1.2 Add reversal relationship

Файлы:

- migration
- `app/models/transaction.rb`
- `app/services/account_operations/reverse_service.rb`

Изменения:

- Добавить `original_transaction_id` в `transactions`.
- Для reversal entry заполнять `original_transaction_id`.
- Добавить уникальный индекс на `original_transaction_id` для reversal-записей.

Варианты реализации:

- Простой вариант: nullable `original_transaction_id` + unique index where `original_transaction_id IS NOT NULL`.
- Более строгий вариант: добавить отдельный `transaction_type: reversal`, но это потребует обновить enum и API contract.

Рекомендация для тестового задания: первый вариант меньше ломает текущий API.

### 1.3 Restrict reverse permission

Файл:

- `app/controllers/api/v1/transactions_controller.rb`

Изменения:

- Для `reverse` разрешить только account, который является `source_account` исходного transfer.
- Если `@account.id != @transaction.source_account_id`, вернуть `403 Forbidden` или `404 Not Found`.
- Добавить concern/helper для authorization только если есть повторное использование. Для одного endpoint достаточно private method.

Рекомендованный ответ:

```json
{
  "status": { "code": 403, "message": "You are not allowed to reverse this transaction." }
}
```

## Phase 2. Money Model

Оценка: 4-8 часов

Зависимости: Phase 0.3

### 2.1 Choose money representation

Рекомендованный прагматичный вариант для текущего проекта:

- Оставить `decimal`.
- Привести `transactions.amount` к scale `2`, чтобы совпадал с `accounts.balance`.
- Валидировать input scale на уровне `parse_amount!`.

Более production-grade вариант:

- Хранить деньги в minor units (`integer` cents).
- Это более надежно, но потребует большего изменения serializers, schema, specs и API formatting.

Для тестового задания лучше выбрать decimal + strict scale: меньше риск регрессий, легче объяснить.

### 2.2 Validate amount precision

Файл:

- `app/controllers/concerns/amount_validatable.rb`

Изменения:

- Принимать только decimal string/number с максимум 2 знаками после точки.
- Явно отклонять `NaN`, infinity, пустые значения, нечисловые строки.
- Нормализовать amount до `BigDecimal` с scale 2.

Пример правила:

```ruby
AMOUNT_FORMAT = /\A\d+(\.\d{1,2})?\z/
```

Дополнительно решить, разрешать ли `100`, `100.0`, `100.00`. Рекомендация: разрешать.

### 2.3 Align transaction amount scale

Файлы:

- migration
- `db/schema.rb`

Изменения:

- Изменить `transactions.amount` с `precision: 19, scale: 4` на `precision: 10, scale: 2` или `precision: 19, scale: 2`.
- Если данных нет или это тестовое задание, миграция простая.
- Если данные могут быть, сначала проверить наличие значений с scale > 2 и решить округление/отказ.

Рекомендация: `precision: 19, scale: 2`, чтобы лимит transaction не был меньше баланса.

## Phase 3. Idempotency For Financial POST

Оценка: 8-12 часов

Зависимости: Phase 0.4

### 3.1 Define API contract

Файл:

- `docs/api.md`

Решить:

- `Idempotency-Key` обязателен или опционален?
- Какие endpoints поддерживаются: `deposit`, `withdraw`, `transfer`, `reverse`.
- Срок хранения ключа.
- Поведение при повторе с другим body.

Рекомендация:

- Для тестового задания сделать key опциональным, но если он передан - строго соблюдать идемпотентность.
- При повторе того же key и body вернуть сохраненный response.
- При повторе key с другим body вернуть `409 Conflict`.

### 3.2 Add idempotency table

Файлы:

- migration
- `app/models/idempotency_key.rb`

Поля:

- `user_id`
- `key`
- `request_method`
- `request_path`
- `request_fingerprint`
- `response_status`
- `response_body`
- `locked_at` или `status`, если нужна защита in-progress requests
- timestamps

Индексы:

- unique `[user_id, key]`
- index по `created_at` для будущей очистки

### 3.3 Add controller concern

Файлы:

- `app/controllers/concerns/idempotent_request.rb`
- `app/controllers/api/v1/accounts_controller.rb`
- `app/controllers/api/v1/transactions_controller.rb`

Изменения:

- Для financial POST endpoints оборачивать выполнение в idempotency handler.
- Считать fingerprint из method, path и normalized params без служебных Rails-полей.
- Сохранять response body/status после успешной операции.
- На повтор возвращать сохраненный response без повторного вызова сервиса.

Важный риск: concurrent одинаковые requests с одним key. Нужно использовать row lock или unique insert + lock, чтобы не выполнить операцию дважды.

## Phase 4. Remove Read Side Effects

Оценка: 3-5 часов

Зависимости: можно делать после Phase 1

### 4.1 Create default account at registration

Файлы:

- `app/controllers/api/v1/auth/registrations_controller.rb`
- `app/models/user.rb`
- specs auth/account resolver

Изменения:

- После успешной регистрации создавать USD account в той же transaction.
- Либо добавить callback `after_create :create_default_account!`, но для прозрачности API лучше явно в registration flow или service.

### 4.2 Split find and create behavior

Файлы:

- `app/models/user.rb`
- `app/services/account_resolver.rb`

Изменения:

- `User#default_account` заменить на `accounts.find_by!(currency: "USD")` для read/operation paths.
- Добавить отдельный метод `create_default_account!` или service для регистрации.
- `AccountResolver#resolve` не должен создавать счет.

### 4.3 Handle missing default account

Файлы:

- `app/controllers/concerns/account_errors.rb`
- request specs

Изменения:

- Если default account отсутствует, вернуть контролируемый `404 Account not found` или `422 Default account is missing`.
- Для текущего UX предпочтительно `404`, потому что resolver уже использует account lookup semantics.

## Phase 5. Database Constraints

Оценка: 4-8 часов

Зависимости: Phase 2 желательно до изменения amount constraints

### 5.1 Add non-null constraints

Файл:

- migration

Изменения:

- `transactions.status`, `transactions.transaction_type` -> `null: false`.
- Убедиться, что существующие records заполнены.

### 5.2 Add check constraints

Файл:

- migration

Constraints:

- `accounts.balance >= 0`
- `accounts.currency IN ('USD', 'EUR')`
- `accounts.status IN ('active', 'holded', 'closed')`
- `transactions.amount > 0`
- `transactions.currency IN ('USD', 'EUR')`
- `transactions.status IN (0, 1, 2, 3)`
- `transactions.transaction_type IN (0, 1, 2)`

### 5.3 Add transaction shape constraints

Файл:

- migration

Rules:

- deposit: `source_account_id IS NULL AND target_account_id IS NOT NULL`
- withdrawal: `source_account_id IS NOT NULL AND target_account_id IS NULL`
- transfer: `source_account_id IS NOT NULL AND target_account_id IS NOT NULL`

Так как enum хранится integer, constraint будет завязан на значения enum. Перед добавлением зафиксировать enum mapping в тестах, чтобы случайное изменение enum не ломало данные незаметно.

## Phase 6. Account Creation Race Handling

Оценка: 3-5 часов

Зависимости: Phase 4

### 6.1 Retry account number collisions

Файл:

- `app/models/account.rb`

Изменения:

- Оставить генерацию номера, но обработать `ActiveRecord::RecordNotUnique` на create.
- Ограничить количество retry, например 3-5 попыток.

Рекомендация: retry лучше разместить в отдельном creation service, а не в callback, но для текущего проекта допустим небольшой `create_default_account!`/factory method.

### 6.2 Use create_or_find_by for default account

Файл:

- `app/models/user.rb`

Изменения:

- Для явного создания default account использовать `create_or_find_by!(currency: "USD")`.
- Обрабатывать unique race на `[user_id, currency]`.

### 6.3 Concurrent spec

Файл:

- `spec/models/user_spec.rb` или service spec

Сценарий:

- Несколько потоков пытаются создать default account для одного user.
- В итоге ровно один USD account.
- Нет необработанного `RecordNotUnique`.

## Phase 7. API Polish

Оценка: 2-4 часа

Зависимости: после функциональных фаз

### 7.1 Rename holded

Файлы:

- migration
- `app/models/account.rb`
- `app/controllers/api/v1/accounts_controller.rb`
- specs
- docs

Варианты:

- `held`
- `on_hold`
- `frozen`

Рекомендация: `on_hold`, потому что лучше читается в API.

Риск: это breaking change для response `status`. Если важно сохранить compatibility, оставить enum value `holded`, но исправить только messages. Для тестового задания лучше показать аккуратность и переименовать.

### 7.2 Normalize response messages

Файлы:

- `app/controllers/api/v1/accounts_controller.rb`
- `app/controllers/concerns/account_errors.rb`
- docs

Примеры:

- `Account placed on hold successfully.`
- `Account activated successfully.`
- `Account closed successfully.`

## Recommended Implementation Order

1. Phase 0: добавить failing regression specs.
2. Phase 1: исправить reverse concurrency и authorization.
3. Phase 2: зафиксировать формат денег.
4. Phase 5: добавить DB constraints, завязанные на уже выбранную money model.
5. Phase 3: добавить idempotency.
6. Phase 4: убрать side effects read endpoints.
7. Phase 6: обработать races создания accounts.
8. Phase 7: полировка naming/messages.

## Verification Commands

Основная проверка:

```bash
docker exec api-rails bundle exec rspec
```

Точечные проверки после фаз:

```bash
docker exec api-rails bundle exec rspec spec/services/account_operations/reverse_service_spec.rb
docker exec api-rails bundle exec rspec spec/requests/api/v1/transactions_spec.rb
docker exec api-rails bundle exec rspec spec/requests/api/v1/accounts_spec.rb
docker exec api-rails bundle exec rspec spec/models/user_spec.rb
```

Если RuboCop и Brakeman установлены в контейнере:

```bash
docker exec api-rails bundle exec rubocop
docker exec api-rails bundle exec brakeman
```
