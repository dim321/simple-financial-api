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
      { source_account: @source_account.reload, target_account: @target_account.reload }
    end

    private

    attr_reader :source_account, :target_account, :amount, :description

    def validate!
      raise Account::InvalidAccountError, "Target account unknown" if target_account.blank?
      raise Account::InvalidAmountError, "Amount must be positive" if amount <= 0
      raise Account::InactiveAccountError, "Source account is not active" unless source_account.active?
      raise Account::InactiveAccountError, "Target account is not active" unless target_account.active?
      raise Account::SelfTransferError, "Cannot transfer to the same account" if source_account.id == target_account.id
      raise Account::DifferentCurrencyError, "Cannot transfer between different currencies" if source_account.currency != target_account.currency
    end

    def perform_transfer
      lock_accounts(source_account, target_account) do
        src = source_account.reload
        tgt = target_account.reload

        raise Account::InsufficientFundsError, "Insufficient funds" if src.balance < amount

        src.update!(balance: src.balance - amount)
        tgt.update!(balance: tgt.balance + amount)
        Transaction.create_transfer!(src, tgt, amount, description: description)
      end
    end

    def lock_accounts(first_account, second_account, &block)
      ordered = [ first_account, second_account ].sort_by(&:id)
      ordered[0].with_lock do
        ordered[1].with_lock(&block)
      end
    end
  end
end
