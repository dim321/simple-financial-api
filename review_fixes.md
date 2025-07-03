# Review fixes

1. **docker compose up --build fails with devise_jwt_secret_key is blank error**
   - The `master.key` file is required for decrypting credentials. It's standard practice not to include `master.key` in the repository for security reasons (attaching `master.key` to this message).

2. **Example requests (curl_examples.txt) are cluttered; main usage examples should be in the README**
   - Moved the examples to the README.

3. **Transferring to non-existent accounts causes 500 errors**
   - Added error handling for transferring to a non-existent account. Please, check spec/services/account_operations/transfer_service_spec.rb:70

4. **Rubocop finds 6 offenses**
   - Fixed.

5. **No tests; CI is failing**
   - Added tests for service objects; CI is not included in the test task, sorry.

6. **No currency conversions; balances can become inconsistent**
   - Handled the `Account::DifferentCurrencyError` with the message 'Cannot transfer between different currencies.' A currency converter is not included in the test task, sorry.

7. **TransactionsController seems unused**
   - `TransactionsController` will be useful for viewing the user's transaction history and transaction details, but I removed it.

8. **Account model and AccountsController have unused/broken methods (e.g., hold, freeze_account)**
   - Unused methods removed.

9. **User model has unused methods (transfer, deposit, withdraw, total_balance)—should be revisited**
   - Unused methods removed.

10. **Commented-out code in UserSerializer**
    - Removed.

11. **Potential race conditions in Account#withdraw; sufficient funds checked before locking**
    - Fixed. Check in `spec/services/account_operations/withdraw_service_spec.rb:97`.

12. **Account#transfer locks only source account; target should also be locked**
    - Fixed.

13. **Use ActiveRecord::Base.transaction instead of self.transaction**
    - Fixed.

14. **Account#deposit, #withdraw, #transfer not wrapped in DB transaction—risks data inconsistency**
    - Fixed.

15. **Business logic is mostly in models—consider moving to service objects**
    - Business logic moved to service objects in `app/services/account_operations/`.