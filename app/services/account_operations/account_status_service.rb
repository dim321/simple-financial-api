module AccountOperations
  class AccountStatusService
    def initialize(account)
      @account = account
    end

    def hold
      account.with_lock do
        validate_active!
        account.on_hold!
      end
      account
    end

    def unhold
      account.with_lock do
        validate_on_hold!
        account.active!
      end
      account
    end

    def close
      account.with_lock do
        validate_zero_balance!
        account.closed!
      end
      account
    end

    private

    attr_reader :account

    def validate_active!
      raise Account::InactiveAccountError, 'Account is not active' unless account.active?
    end

    def validate_on_hold!
      raise Account::InactiveAccountError, 'Account is not on hold' unless account.on_hold?
    end

    def validate_zero_balance!
      raise Account::NonZeroBalanceError, 'Cannot close account with positive balance' if account.balance.positive?
    end
  end
end
