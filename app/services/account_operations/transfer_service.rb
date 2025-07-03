module AccountOperations
  class TransferService
    def initialize(source_account, target_account, amount, description: nil)
      @source_account = source_account
      @target_account = target_account
      @amount = amount
      @description = description
    end

    def call
      ActiveRecord::Base.transaction do
        validate!
        perform_transfer
      end
      { source_account: @source_account, target_account: @target_account }
    end

    private

    attr_reader :source_account, :target_account, :amount, :description

    def validate!
      raise Account::InvalidAccountError, 'Target account unknown' if target_account.blank?
      raise Account::InvalidAmountError, 'Amount must be positive' if amount <= 0
      raise Account::InactiveAccountError, 'Source account is not active' unless source_account.active?
      raise Account::InactiveAccountError, 'Target account is not active' unless target_account.active?
      raise Account::InsufficientFundsError, 'Insufficient funds' if source_account.balance < amount
      raise Account::SelfTransferError, 'Cannot transfer to the same account' if source_account.id == target_account.id
      raise Account::DifferentCurrencyError, 'Cannot transfer between different currencies' if source_account.currency != target_account.currency
    end

    def perform_transfer
      source_account.with_lock do
        target_account.with_lock do
          source_account.update!(balance: source_account.balance - amount)
          target_account.update!(balance: target_account.balance + amount)
          Transaction.create_transfer!(source_account, target_account, amount, description: description)
        end
      end
    end
  end
end
