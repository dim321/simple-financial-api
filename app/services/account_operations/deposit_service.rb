module AccountOperations
  class DepositService
    def initialize(account, amount, description: nil)
      @account = account
      @amount = amount
      @description = description
    end

    def call
      account.with_lock do
        validate!
        perform_deposit
      end
      @account
    end

    private

    attr_reader :account, :amount, :description

    def validate!
      raise Account::InvalidAmountError, "Amount must be positive" if amount_cents <= 0
      raise Account::InactiveAccountError, 'Account is not active' unless account.active?
    end

    def perform_deposit
      ActiveRecord::Base.transaction do
        account.update!(balance_cents: account.balance_cents + amount_cents)
        Transaction.create_deposit!(account, amount, description: description)
      end
    end

    def amount_cents
      @amount_cents ||= MoneyAmount.to_cents(amount)
    rescue MoneyAmount::InvalidAmountError
      raise Account::InvalidAmountError, "Amount is required or invalid"
    end
  end
end
