module AccountOperations
  class WithdrawService
    def initialize(account, amount, description: nil)
      @account = account
      @amount = amount
      @description = description
    end

    def call
      account.with_lock do
        validate!
        account.reload
        raise Account::InsufficientFundsError, "Insufficient funds" if account.balance_cents < amount_cents

        perform_withdrawal
      end
      @account.reload
    end

    private

    attr_reader :account, :amount, :description

    def validate!
      raise Account::InvalidAmountError, "Amount must be positive" if amount_cents <= 0
      raise Account::InactiveAccountError, "Account is not active" unless account.active?
    end

    def perform_withdrawal
      ActiveRecord::Base.transaction do
        account.update!(balance_cents: account.balance_cents - amount_cents)
        Transaction.create_withdrawal!(account, amount, description: description)
      end
    end

    def amount_cents
      @amount_cents ||= MoneyAmount.to_cents(amount)
    rescue MoneyAmount::InvalidAmountError
      raise Account::InvalidAmountError, "Amount is required or invalid"
    end
  end
end
