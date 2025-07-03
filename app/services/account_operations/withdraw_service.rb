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
        perform_withdrawal
      end
      @account
    end

    private

    attr_reader :account, :amount, :description

    def validate!
      raise Account::InvalidAmountError, 'Amount must be positive' if amount <= 0
      raise Account::InactiveAccountError, 'Account is not active' unless account.active?
      raise Account::InsufficientFundsError, 'Insufficient funds' if account.balance < amount
    end

    def perform_withdrawal
      ActiveRecord::Base.transaction do
        account.update!(balance: account.balance - amount)
        Transaction.create_withdrawal!(account, amount, description: description)
      end
    end
  end
end
