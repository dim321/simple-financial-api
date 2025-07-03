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
      raise Account::InvalidAmountError, 'Amount must be positive' if amount <= 0
      raise Account::InactiveAccountError, 'Account is not active' unless account.active?
    end

    def perform_deposit
      ActiveRecord::Base.transaction do
        account.update!(balance: account.balance + amount)
        Transaction.create_deposit!(account, amount, description: description)
      end
    end
  end
end
