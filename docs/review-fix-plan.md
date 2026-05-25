# План исправлений по code review

Документ описывает план работ для устранения замечаний code review репозитория **Simple Financial API**.

**Ветка:** `review_fix`  
**База:** `main`  
**Оценка:** ~3–4 рабочих дня

---

## Цели

1. Корректная финансовая логика под конкурентной нагрузкой (блокировки, проверка баланса).
2. Согласованный API: параметр `currency` / выбор счёта работает во всех операциях.
3. Целостная доменная модель (ассоциации, ledger, единая валюта по умолчанию).
4. Завершённые маршруты или их осознанное удаление.
5. Единая аутентификация через Devise JWT с отзывом токена при logout.
6. CI запускает RSpec; тесты покрывают исправленные сценарии.
7. Базовый security hardening (CORS, PII, валидация входа).

---

## Критерии приёмки (Definition of Done)

- [x] `bundle exec rspec` — 0 failures (расширенный набор по новым сценариям).
- [x] GitHub Actions запускает RSpec, не только пустой Minitest.
- [x] Concurrent transfer: при balance 100 два параллельных transfer по 80 → один успех, один `InsufficientFundsError`, balance = 20.
- [x] `currency` в deposit/withdraw/transfer/balance выбирает нужный счёт пользователя.
- [x] Logout инвалидирует JWT (повторный запрос со старым токеном → 401).
- [x] Нет мёртвых routes: `index`, `transactions`, `reverse` реализованы **или** удалены из `routes.rb` с обновлением README.
- [x] `bin/rubocop` без новых проблем в изменённых файлах.
- [x] README и примеры curl актуальны (`docs/api.md`).
- [ ] `bin/brakeman` — прогнать перед merge.
- [ ] **Idempotency-Key** — отложено (см. `docs/api.md`).

---

## Контракт API (целевое поведение)

### Выбор счёта

Для операций над счётом текущего пользователя (deposit, withdraw, balance, hold, unhold, close, transfer sender):

| Приоритет | Параметр | Поведение |
|-----------|----------|-----------|
| 1 | `account_number` | Счёт пользователя с этим номером |
| 2 | `account_id` / `params[:id]` | Счёт по id в scope `current_user.accounts` |
| 3 | `currency` | Существующий счёт в валюте (**find**, без автосоздания) |
| 4 | (нет параметров) | `default_account` (USD) |

Для transfer получателя:

| Параметр | Поведение |
|----------|-----------|
| `recipient_email` + `currency` | Счёт получателя в указанной валюте |
| Отсутствие счёта / пользователя | `422` с единым сообщением (без user enumeration) |

### Сумма

- `amount` обязателен, числовой, строго `> 0`.
- `nil`, пустая строка, нечисловое значение → `422`, сообщение вроде `Amount is required or invalid`.
- Не использовать `params[:amount].to_d` без предварительной проверки (иначе `nil` → `0`).

### Ответы

Формат без изменений:

```json
{
  "status": { "code": 200, "message": "..." },
  "data": { ... }
}
```

---

## Фаза 0. Подготовка

**Оценка:** 2–4 часа

| # | Задача | Результат |
|---|--------|-----------|
| 0.1 | Зафиксировать контракт API (см. выше) | [docs/api.md](./api.md) |
| 0.2 | Согласовать решение по мёртвым routes | Реализовать transactions API **или** удалить из routes |
| 0.3 | Чеклист приёмки в PR | Секция DoD в описании PR |

---

## Фаза 1. Критичная финансовая логика

**Оценка:** 6–8 часов  
**Зависимости:** Фаза 0

### 1.1 Race condition в TransferService

**Файлы:**

- `app/services/account_operations/transfer_service.rb`
- `spec/services/account_operations/transfer_service_spec.rb`

**Изменения:**

1. В `validate!` оставить только проверки, не зависящие от баланса под lock:
   - target present, amount > 0, accounts active, not self-transfer, same currency.
2. В `perform_transfer` внутри `with_lock`:
   - перечитать баланс источника;
   - `raise InsufficientFundsError` если `balance < amount`;
   - обновить балансы.
3. Блокировать счета в порядке `sort_by(&:id)` для предотвращения deadlock.

**Тесты:**

- Два потока: balance 100, transfer 80 × 2 → один успех, один `InsufficientFundsError`, balance 20.
- Сохранить существующий concurrent-тест (4 × 30).

### 1.2 Race condition в WithdrawService

**Файлы:**

- `app/services/account_operations/withdraw_service.rb`
- `spec/services/account_operations/withdraw_service_spec.rb`

**Изменения:** проверку `balance >= amount` перенести внутрь `with_lock` перед списанием (аналогично transfer).

### 1.3 Resolver счёта и параметр currency

**Новые файлы:**

- `app/services/account_resolver.rb` (или `app/controllers/concerns/account_resolvable.rb`)

**Изменения:**

- `app/controllers/api/v1/accounts_controller.rb` — все операции через resolver.
- `app/models/user.rb` — `account_in_currency` только `find_by`, без `find_or_create_by!` в операциях.
- `set_recipient_account` — счёт получателя в `params[:currency]`.

**Тесты (request):**

- Два счёта (USD, EUR); deposit в EUR; balance по currency.
- Transfer с `recipient_email` и `currency`.

---

## Фаза 2. Доменная модель и ledger

**Оценка:** 6–8 часов  
**Зависимости:** Фаза 1

### 2.1 Исправить ассоциацию Account#transactions

**Файлы:**

- `app/models/account.rb`
- `app/models/user.rb`
- все вызовы `account.transactions` как scope

**Изменения:**

1. Удалить переопределение метода `def transactions`.
2. Оставить `has_many` или явные `outgoing_transactions` / `incoming_transactions`.
3. Добавить `def ledger_entries` → `Transaction.for_account(self).recent`.

### 2.2 Одна запись на transfer

**Файлы:**

- `app/models/transaction.rb`
- `app/services/account_operations/transfer_service.rb`
- `spec/factories/transactions.rb`
- `spec/services/account_operations/transfer_service_spec.rb`

**Изменения:**

- `Transaction.create_transfer!` создаёт **одну** запись: `source_account`, `target_account`, положительный `amount`, `transaction_type: :transfer`, `status: :completed`.
- Убрать вторую запись с отрицательным amount и перепутанными FK.

**Тесты:** `change(Transaction, :count).by(1)` для успешного transfer.

### 2.3 Единая валюта по умолчанию

**Файлы:**

- `app/models/account.rb` (`set_default_currency`)

**Изменения:** `self.currency ||= 'USD'` (согласовать с schema и `User#default_account`).

---

## Фаза 3. API, маршруты, валидация

**Оценка:** 6–8 часов  
**Зависимости:** Фазы 1–2

### 3.1 Реализация или удаление мёртвых routes

**Рекомендация:** реализовать минимальный MVP.

| Endpoint | Controller | Действие |
|----------|------------|----------|
| `GET /api/v1/accounts` | `AccountsController#index` | Список счетов `current_user` |
| `GET /api/v1/accounts/:account_id/transactions` | `TransactionsController#index` | Ledger счёта |
| `GET /api/v1/accounts/:account_id/transactions/:id` | `TransactionsController#show` | Одна операция |
| `POST .../transactions/:id/reverse` | `TransactionsController#reverse` | Откат (MVP: transfer) |

**Новые файлы:**

- `app/controllers/api/v1/transactions_controller.rb`
- `app/services/account_operations/reverse_service.rb`
- `spec/requests/api/v1/transactions_spec.rb`

**Reverse (MVP):**

- Доступно для `completed` transfer.
- Атомарно: вернуть балансы, пометить исходную `reversed`, создать запись reversal (или одна compensating transaction — зафиксировать в коде).

**Альтернатива:** удалить nested `transactions` и `reverse` из `config/routes.rb` + обновить README (если в ТЗ история не требуется).

### 3.2 Валидация входных данных

**Файлы:**

- `app/controllers/api/v1/accounts_controller.rb`
- опционально `app/validators/` или private methods

| Поле | Правило |
|------|---------|
| `amount` | presence, numeric, > 0 |
| `currency` | optional; whitelist или существующие валюты user |
| `recipient_email` | presence для transfer; format email |

### 3.3 DRY для ошибок

**Файл:** `app/controllers/concerns/account_errors.rb`

1. Базовый класс `Account::OperationError < StandardError` или hash-маппинг exception → JSON.
2. Удалить неиспользуемые `TargetAccountInactiveError`, `SameAccountError` **или** начать использовать.
3. `ActiveRecord::RecordNotFound` — один обработчик (только в `AuthenticationErrors` **или** только в `AccountErrors`).

---

## Фаза 4. Аутентификация

**Оценка:** 4–6 часов  
**Зависимости:** можно параллельно с Фазой 2 после Фазы 1

### 4.1 Единый путь через Devise JWT

**Файлы:**

- `app/controllers/application_controller.rb`
- `app/controllers/api/v1/auth/sessions_controller.rb`
- `app/controllers/api/v1/auth/registrations_controller.rb`
- `spec/requests/api/v1/auth_spec.rb`

**Изменения:**

1. Удалить `authenticate_user_from_token!` с ручным `JWT.decode`.
2. Использовать `before_action :authenticate_user!` для защищённых контроллеров.
3. `skip_before_action :authenticate_user!` для sign_up, sign_in.
4. `SessionsController#respond_to_on_destroy`: стандартный `sign_out` / Devise flow для **JTIMatcher** (отзыв `jti`).
5. Убрать дублирующий decode JWT в `respond_to_on_destroy`.

### 4.2 User#jwt_token

Удалить из модели, если не используется в production-коде; при необходимости оставить в test helpers.

**Тесты:**

- sign_in → authorized request OK;
- sign_out → same token → 401;
- expired token → 401.

---

## Фаза 5. Безопасность

**Оценка:** 3–5 часов (минимум 2 ч без idempotency)  
**Зависимости:** Фазы 3–4

| # | Задача | Файлы | MVP |
|---|--------|-------|-----|
| 5.1 | CORS | `config/initializers/cors.rb` | `ENV['CORS_ORIGINS']`, не `*` в production |
| 5.2 | PII в serializer | `app/serializers/account_serializer.rb` | Убрать email из nested user или view `:minimal` |
| 5.3 | Rate limiting | Gem `rack-attack`, initializer | Throttle `POST .../sign_in`, `POST .../transfer` |
| 5.4 | Idempotency | `idempotency_keys` table + concern | **Опционально:** только transfer; иначе TODO в README |
| 5.5 | Пароль | `app/models/user.rb`, factories | min 8 символов (обновить factories/specs) |

---

## Фаза 6. Тесты и CI

**Оценка:** 4–6 часов  
**Зависимости:** Фазы 1–5

### 6.1 CI

**Файл:** `.github/workflows/ci.yml`

```yaml
run: bin/rails db:test:prepare && bundle exec rspec
```

- Убрать или оставить один smoke Minitest — не дублировать фреймворки.
- Проверить `RAILS_MASTER_KEY` / credentials для JWT в test.

### 6.2 Новые и обновлённые specs

| Область | Файл | Сценарии |
|---------|------|----------|
| Transfer race | `transfer_service_spec.rb` | 2 × 80 при balance 100 |
| Withdraw race | `withdraw_service_spec.rb` | аналогично |
| Currency | `accounts_spec.rb` | multi-currency deposit/balance |
| Transactions | `transactions_spec.rb` | index, show, reverse |
| Auth | `auth_spec.rb` | logout revokes token |
| Index | `accounts_spec.rb` | GET /accounts |

### 6.3 README

- Исправить опечатки и двойной `/` в URL.
- Описать выбор счёта (`currency`, `account_number`).
- Заменить «пришлите master.key» на `rails credentials:edit` / env для CI.
- Синхронизировать примеры curl с контрактом API.

---

## Фаза 7. Качество кода и polish

**Оценка:** 2–4 часа  
**Зависимости:** Фаза 6

| # | Задача | Файлы |
|---|--------|-------|
| 7.1 | Enum `holded` → `held` | Миграция значений **или** alias в enum без смены DB |
| 7.2 | `Account#transfer` | Возвращать `{ source:, target: }` как `TransferService` |
| 7.3 | Serializer helper | `render_account(account)` в controller/base |
| 7.4 | RuboCop | Все изменённые файлы |

---

## Порядок выполнения

```
Фаза 0 (подготовка)
    ↓
Фаза 1 (locks + resolver) ──┬──→ Фаза 4 (auth)
    ↓                       │
Фаза 2 (модель + ledger)    │
    ↓                       │
Фаза 3 (routes + validation)←┘
    ↓
Фаза 5 (security)
    ↓
Фаза 6 (CI + specs)
    ↓
Фаза 7 (polish)
```

**Параллельно после Фазы 1:** Фаза 4 и Фаза 2 — в отдельных коммитах.

---

## Разбивка на коммиты / PR

| # | Commit message (пример) | Фаза |
|---|---------------------------|------|
| 1 | `fix: validate balance under row lock for transfer and withdraw` | 1.1, 1.2 |
| 2 | `feat: resolve account by currency or account_number` | 1.3 |
| 3 | `refactor: fix Account transactions association and single transfer record` | 2.1, 2.2 |
| 4 | `fix: unify default currency to USD` | 2.3 |
| 5 | `feat: accounts index and transactions API with reverse` | 3.1 |
| 6 | `feat: strict amount validation and DRY account errors` | 3.2, 3.3 |
| 7 | `refactor: unify Devise JWT authentication and logout revocation` | 4 |
| 8 | `chore: security hardening CORS PII rate limit` | 5 |
| 9 | `test: run RSpec in CI and expand request specs` | 6 |
| 10 | `docs: update README and review fix plan` | 6.3, 7 |

---

## Минимальный MVP (если сроки жмут)

Обязательно закрыть review:

- ✅ Фаза 1 целиком
- ✅ Фаза 2.1, 2.2, 2.3
- ✅ Фаза 3.2, 3.3
- ✅ Фаза 4
- ✅ Фаза 6

Отложить с явным TODO в README:

- Idempotency (5.4) — таблица + header
- Reverse только для transfer (упростить 3.1)
- Rate limit — только sign_in

**Мёртвые routes:** нельзя оставить как есть — либо реализовать index + transactions index, либо удалить из routes.

---

## Матрица: замечание review → фаза

| Замечание | Фаза |
|-----------|------|
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
| `holded`, serializer boilerplate | 7 |

---

## Ссылки

- Исходное ревью: [code-review.md](./code-review.md)
- README: `README.md`
- Маршруты: `config/routes.rb`
