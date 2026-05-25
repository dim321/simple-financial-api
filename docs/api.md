# API contract

Base URL: `http://localhost:3000`

All protected endpoints require header:

```
Authorization: Bearer <jwt>
```

## Response envelope

```json
{
  "status": { "code": 200, "message": "..." },
  "data": {}
}
```

Errors use the same `status` object; HTTP status mirrors `status.code` where applicable.

## Authentication

| Method | Path | Auth |
|--------|------|------|
| POST | `/api/v1/auth` | No — register |
| POST | `/api/v1/auth/sign_in` | No — returns JWT in `Authorization` response header |
| DELETE | `/api/v1/auth/sign_out` | Yes — revokes JWT (`jti` rotation) |

Password minimum length: **8** characters.

## Supported currencies

`USD`, `EUR` — used when creating accounts and selecting accounts for operations.

## Account selection

For `deposit`, `withdraw`, `transfer` (sender), `balance`, `hold`, `unhold`, `close`, and nested `transactions`:

| Priority | Parameter | Behavior |
|----------|-----------|----------|
| 1 | `account_number` | User's account with this number |
| 2 | `account_id` / route `:id` | User's account by id |
| 3 | `currency` | User's existing account in that currency |
| 4 | (none) | Default USD account (`find_or_create` on first access) |

Transfer recipient: `recipient_email` + optional `currency` (default `USD`). Unknown recipient or missing account → `422` `Target account unknown`.

## Amount

- Required for `deposit`, `withdraw`, `transfer`.
- Must be numeric and **> 0**.
- Invalid or missing → `422` `Amount is required or invalid`.

## Accounts

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/v1/accounts` | List user accounts |
| POST | `/api/v1/accounts` | Body: `{ "account": { "currency": "USD" } }` |
| GET | `/api/v1/accounts/:id` | Show account |
| GET | `/api/v1/accounts/balance` | Optional `currency` / `account_number` |
| POST | `/api/v1/accounts/deposit` | `amount`, optional `currency` |
| POST | `/api/v1/accounts/withdraw` | `amount`, optional `currency` |
| POST | `/api/v1/accounts/transfer` | `amount`, `recipient_email`, optional `currency` |
| POST | `/api/v1/accounts/hold` | |
| POST | `/api/v1/accounts/unhold` | |
| POST | `/api/v1/accounts/close` | Zero balance required |

## Transactions

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/v1/accounts/:account_id/transactions` | Ledger for account |
| GET | `/api/v1/accounts/:account_id/transactions/:id` | Single entry |
| POST | `/api/v1/accounts/:account_id/transactions/:id/reverse` | Completed **transfer** only; creates reversal ledger entry |

## Rate limiting

`rack-attack` throttles:

- `POST /api/v1/auth/sign_in` — 10 requests / minute / IP
- `POST /api/v1/accounts/transfer` — 30 requests / minute / IP

Response when throttled: `429` with `Too many requests. Retry later.`

## Planned (not implemented)

- **Idempotency-Key** header for financial POST operations
