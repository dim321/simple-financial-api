# Simple Financial API

Test task: financial REST API.

- Ruby 3.4.4
- Rails 8

## Quick start

1. Clone the repository.
2. Configure secrets (choose one):
   - **Docker:** credentials are provided via `docker-compose.yml` (`DEVISE_JWT_SECRET_KEY` in test; development uses `config/master.key` if present).
   - **Local:** run `EDITOR="nano" bin/rails credentials:edit` and set `devise_jwt_secret_key`, or export `DEVISE_JWT_SECRET_KEY` for JWT in non-docker environments.
3. Run `docker compose up --build`
4. API: http://localhost:3000

Full contract: [docs/api.md](docs/api.md)


## Tests

```bash
docker exec -it api-rails bundle exec rspec
```

Currently **120+ examples** (request, service, and model specs).

## Account selection

`deposit`, `withdraw`, `transfer`, and `balance` accept optional query/body params:

- `currency` — `USD` or `EUR` (must already exist for the user)
- `account_number` — 20-digit account number

Without them, the user's default **USD** account is used.

The default USD account is created during registration. Account lookup endpoints do not create accounts implicitly.

## Environment variables

| Variable | Purpose |
|----------|---------|
| `CORS_ORIGINS` | Comma-separated allowed origins (default `http://localhost:3000`) |
| `DEVISE_JWT_SECRET_KEY` | JWT signing secret (test/CI fallback in `config/initializers/devise.rb`) |
| `TEST_DATABASE_URL` | PostgreSQL URL for test DB (see `config/database.yml`) |

## Example requests

### Register

```bash
curl -X POST http://localhost:3000/api/v1/auth \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"user@test.dom","password":"password123","name":"John"}}'
```

### Sign in (JWT in `Authorization` response header)

```bash
curl -i -X POST http://localhost:3000/api/v1/auth/sign_in \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"user@test.dom","password":"password123"}}'
```

### Balance (default USD account)

```bash
curl -X GET "http://localhost:3000/api/v1/accounts/balance" \
  -H "Authorization: Bearer <token>"
```

### Balance for EUR account

```bash
curl -X GET "http://localhost:3000/api/v1/accounts/balance?currency=EUR" \
  -H "Authorization: Bearer <token>"
```

### Deposit

```bash
curl -X POST http://localhost:3000/api/v1/accounts/deposit \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"amount":1000,"currency":"USD"}'
```

### Transfer

```bash
curl -X POST http://localhost:3000/api/v1/accounts/transfer \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"amount":100,"currency":"USD","recipient_email":"peer@test.dom"}'
```

### List transactions

```bash
curl -X GET "http://localhost:3000/api/v1/accounts/<account_id>/transactions" \
  -H "Authorization: Bearer <token>"
```

### Reverse a transfer

```bash
curl -X POST "http://localhost:3000/api/v1/accounts/<account_id>/transactions/<transaction_id>/reverse" \
  -H "Authorization: Bearer <token>"
```

### Sign out (invalidates JWT)

```bash
curl -X DELETE http://localhost:3000/api/v1/auth/sign_out \
  -H "Authorization: Bearer <token>"
```
