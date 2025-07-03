Test task: Simple financial API

Ruby 3.4.4

Rails 8

# How to run the application

1. Clone the repository.
2. Ask me for master.key file and place it into /config directory (It's standart practice to not push master.key into repository because security reason)
3. Run `docker compose up --build`
4. Check main usage examples below and try it in console.
5. Enjoy

## Run tests in docker container:
```bash
docker exec -it api-rails bundle exec rspec
Randomized with seed 63774
................................................................................

Finished in 18.7 seconds (files took 1.92 seconds to load)
79 examples, 0 failures


```

## Main usage examples:

### New user registration:
```curl
curl -X POST http://localhost:3000/api/v1/auth \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
    "email": "test5@test.dom",
    "password": "password",
    "name": "John"
        }
  }'
{"status":{"code":200,"message":"Signed up successfully."},"data":{"id":951,"email":"test5@test.dom","name":"John"}}
```

### User sign-in (you can see jwt token in responce authorization header):
```
curl -i -X POST http://localhost:3000//api/v1/auth/sign_in \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
    "email": "test@test.dom",
    "password": "password"
        }
  }'

HTTP/1.1 200 OK
x-frame-options: SAMEORIGIN
x-xss-protection: 0
x-content-type-options: nosniff
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
content-type: application/json; charset=utf-8
authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI5OTNhMTMzMS04MDAwLTQ0YTItYTRmZC01MWY1ZThhMzVjZjQiLCJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzUxMjYwMjQ5LCJleHAiOjE3NTEyNjc0NDl9.j7roxYdCKtlbQbk3UM5Pnd425AQckwnE9acqHpANRvc
etag: W/"16c5a796274bad59ab1a1644985f12d1"
cache-control: max-age=0, private, must-revalidate
x-request-id: 477e32ce-63e5-4f73-b411-c22c362ed4cf
x-runtime: 0.237118
server-timing: start_processing.action_controller;dur=0.01, sql.active_record;dur=0.87, instantiation.active_record;dur=7.01, process_action.action_controller;dur=205.54
vary: Origin
Content-Length: 113

{"status":{"code":200,"message":"Logged in successfully."},"data":{"id":1,"email":"test@test.dom","name":"John"}}
```
### User logout (jwt token in header required):
```
curl -X DELETE http://localhost:3000/api/v1/auth/sign_out \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI5OTNhMTMzMS04MDAwLTQ0YTItYTRmZC01MWY1ZThhMzVjZjQiLCJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzUxMjYwMjQ5LCJleHAiOjE3NTEyNjc0NDl9.j7roxYdCKtlbQbk3UM5Pnd425AQckwnE9acqHpANRvc"

{"status":{"code":200,"message":"Logged out successfully."}}
```
### User create account:
```
curl -i -X POST http://localhost:3000/api/v1/accounts   \
  -H "Content-Type: application/json"  \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIxMzU4Y2RhNC02MWNjLTQ0NTktYjM3YS1mZTU0ZmJhZTIxMDEiLCJzdWIiOiI5NTEiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE3NTEzMzQ1MzMsImV4cCI6MTc1MTM0MTczM30.8n83rjGxwy0HbrxL8x5y9B3LS4IG9JFiOKM9JsM7iag"  \
  -d '{
    "account": {
    "currency": "USD"
        }
  }'
HTTP/1.1 201 Created
x-frame-options: SAMEORIGIN
x-xss-protection: 0
x-content-type-options: nosniff
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
content-type: application/json; charset=utf-8
vary: Accept, Origin
etag: W/"e4b5612584742e18f161034953b39d98"
cache-control: max-age=0, private, must-revalidate
x-request-id: ce2a26bd-31ab-4444-ab92-947ec0cca573
x-runtime: 0.099684
server-timing: start_processing.action_controller;dur=0.01, sql.active_record;dur=11.90, instantiation.active_record;dur=0.03, start_transaction.active_record;dur=0.00, transaction.active_record;dur=44.31, process_action.action_controller;dur=90.24
Content-Length: 297

{"status":{"code":201,"message":"Account created successfully."},"data":{"id":874,"account_number":"25590455256549357963","balance":"0.0","currency":"USD","status":"active","created_at":"2025-07-01T01:49:46.671Z","updated_at":"2025-07-01T01:49:46.671Z","user":{"id":951,"email":"test5@test.dom"}}}
```
### User check account balance:
```
curl -i -X GET http://localhost:3000/api/v1/accounts/balance  \
-H "Content-Type: application/json"   \
-H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIxMzU4Y2RhNC02MWNjLTQ0NTktYjM3YS1mZTU0ZmJhZTIxMDEiLCJzdWIiOiI5NTEiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE3NTEzMzQ1MzMsImV4cCI6MTc1MTM0MTczM30.8n83rjGxwy0HbrxL8x5y9B3LS4IG9JFiOKM9JsM7iag"

HTTP/1.1 200 OK
x-frame-options: SAMEORIGIN
x-xss-protection: 0
x-content-type-options: nosniff
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
content-type: application/json; charset=utf-8
vary: Accept, Origin
etag: W/"4a6f99b6b10a047966a9e01245875627"
cache-control: max-age=0, private, must-revalidate
x-request-id: 2572d7b9-dfee-4f67-bf96-b7986e2a3a26
x-runtime: 0.053535
server-timing: start_processing.action_controller;dur=0.01, sql.active_record;dur=1.11, instantiation.active_record;dur=8.41, process_action.action_controller;dur=37.98
Content-Length: 166

{"status":{"code":200,"message":"Balance."},"data":{"account_number":"25590455256549357963","balance":"0.0","currency":"USD","updated_at":"2025-07-01T01:49:46.671Z"}}
```
### User make deposit:
```
curl -i -X POST http://localhost:3000/api/v1/accounts/deposit  \
  -H "Content-Type: application/json"  \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIxMzU4Y2RhNC02MWNjLTQ0NTktYjM3YS1mZTU0ZmJhZTIxMDEiLCJzdWIiOiI5NTEiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE3NTEzMzQ1MzMsImV4cCI6MTc1MTM0MTczM30.8n83rjGxwy0HbrxL8x5y9B3LS4IG9JFiOKM9JsM7iag" \
  -d '{
  "amount": 1000,
  "currency": "USD"
  }'

HTTP/1.1 200 OK
x-frame-options: SAMEORIGIN
x-xss-protection: 0
x-content-type-options: nosniff
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
content-type: application/json; charset=utf-8
vary: Accept, Origin
etag: W/"55ff55d2e65d58401c30dfbc72913095"
cache-control: max-age=0, private, must-revalidate
x-request-id: d354da57-e783-47de-a1f8-515711dcb3a1
x-runtime: 0.131462
server-timing: start_processing.action_controller;dur=0.00, sql.active_record;dur=21.48, instantiation.active_record;dur=1.73, start_transaction.active_record;dur=0.00, transaction.active_record;dur=92.13, process_action.action_controller;dur=124.06
Content-Length: 290

{"status":{"code":200,"message":"Deposit successful."},"data":{"id":874,"account_number":"25590455256549357963","balance":"1000.0","currency":"USD","status":"active","created_at":"2025-07-01T01:49:46.671Z","updated_at":"2025-07-01T02:07:58.111Z","user":{"id":951,"email":"test5@test.dom"}}}
```
### User make withdrawal:
```
curl -i -X POST http://localhost:3000/api/v1/accounts/withdraw \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIxMzU4Y2RhNC02MWNjLTQ0NTktYjM3YS1mZTU0ZmJhZTIxMDEiLCJzdWIiOiI5NTEiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE3NTEzMzQ1MzMsImV4cCI6MTc1MTM0MTczM30.8n83rjGxwy0HbrxL8x5y9B3LS4IG9JFiOKM9JsM7iag" \
  -d '{
   "amount": 75,
   "currency": "USD"
    }'
HTTP/1.1 200 OK
x-frame-options: SAMEORIGIN
x-xss-protection: 0
x-content-type-options: nosniff
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
content-type: application/json; charset=utf-8
vary: Accept, Origin
etag: W/"66fcb4190b7c6fc49276fd3ff860e7b6"
cache-control: max-age=0, private, must-revalidate
x-request-id: c6d52c43-76f9-466b-9ad0-b6d5c1a5d218
x-runtime: 0.063667
server-timing: start_processing.action_controller;dur=0.01, sql.active_record;dur=15.54, instantiation.active_record;dur=0.88, start_transaction.active_record;dur=0.00, transaction.active_record;dur=45.26, process_action.action_controller;dur=57.39
Content-Length: 292

{"status":{"code":200,"message":"Withdrawal successful."},"data":{"id":874,"account_number":"25590455256549357963","balance":"925.0","currency":"USD","status":"active","created_at":"2025-07-01T01:49:46.671Z","updated_at":"2025-07-01T02:13:57.014Z","user":{"id":951,"email":"test5@test.dom"}}}
```
### User transfer money to friend:
```
curl -i -X POST http://localhost:3000/api/v1/accounts/transfer  \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIxMzU4Y2RhNC02MWNjLTQ0NTktYjM3YS1mZTU0ZmJhZTIxMDEiLCJzdWIiOiI5NTEiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE3NTEzMzQ1MzMsImV4cCI6MTc1MTM0MTczM30.8n83rjGxwy0HbrxL8x5y9B3LS4IG9JFiOKM9JsM7iag"  \
  -d '{
    "amount": 175,
    "currency": "USD",
    "recipient_email": "test@test.dom"
}'

HTTP/1.1 200 OK
x-frame-options: SAMEORIGIN
x-xss-protection: 0
x-content-type-options: nosniff
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
content-type: application/json; charset=utf-8
vary: Accept, Origin
etag: W/"4dec05f6b381b373bf03531635c92f38"
cache-control: max-age=0, private, must-revalidate
x-request-id: a89e9978-b3c6-44cc-bb14-3aa37138b5b2
x-runtime: 0.216967
server-timing: sql.active_record;dur=31.12, start_processing.action_controller;dur=0.00, instantiation.active_record;dur=17.77, start_transaction.active_record;dur=0.00, transaction.active_record;dur=86.96, process_action.action_controller;dur=144.92
Content-Length: 536

{"status":{"code":200,"message":"Transfer successful."},"data":{"sender":{"id":874,"account_number":"25590455256549357963","balance":"400.0","currency":"USD","status":"active","created_at":"2025-07-01T01:49:46.671Z","updated_at":"2025-07-01T02:38:41.275Z","user":{"id":951,"email":"test5@test.dom"}},"recipient":{"id":1,"account_number":"85434567629614924283","balance":"1100.0","currency":"USD","status":"active","created_at":"2025-06-07T04:09:08.329Z","updated_at":"2025-07-01T02:38:41.284Z","user":{"id":1,"email":"test@test.dom"}}}}
```
### User try to transfer money to unknown recipient:
```
curl -i -X POST http://localhost:3000/api/v1/accounts/transfer   -H "Content-Type: application/json"   -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIxMzU4Y2RhNC02MWNjLTQ0NTktYjM3YS1mZTU0ZmJhZTIxMDEiLCJzdWIiOiI5NTEiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE3NTEzNDQ2ODgsImV4cCI6MTc1MTM1MTg4OH0.S6PwYN54Im_hELUiDeUIYP7Z698iWac_AFhLL6Olmo8"   -d '{
    "amount": 175,
    "currency": "USD",
    "recipient_email": "unknown_test@test.dom"
}'
HTTP/1.1 422 Unprocessable Content
x-frame-options: SAMEORIGIN
x-xss-protection: 0
x-content-type-options: nosniff
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
content-type: application/json; charset=utf-8
vary: Accept, Origin
cache-control: no-cache
x-request-id: bf7ad690-554c-472c-8e20-ace00a216ad1
x-runtime: 0.070161
server-timing: sql.active_record;dur=3.87, start_processing.action_controller;dur=0.00, instantiation.active_record;dur=3.43, process_action.action_controller;dur=12.35
Content-Length: 58

{"status":{"code":422,"message":"Target account unknown"}}
```