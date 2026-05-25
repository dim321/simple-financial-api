module AccountOperations
  class ReverseService
    class NotReversibleError < StandardError; end

    def initialize(transaction)
      @transaction = transaction
    end

    def call
      validate!

      ActiveRecord::Base.transaction do
        reverse_transfer!
      end

      @transaction.reload
    end

    private

    attr_reader :transaction

    def validate!
      unless transaction.transaction_type_transfer? && transaction.status_completed?
        raise NotReversibleError, "Only completed transfers can be reversed"
      end

      raise Account::InactiveAccountError, "Source account is not active" unless transaction.source_account.active?
      raise Account::InactiveAccountError, "Target account is not active" unless transaction.target_account.active?
    end

    def reverse_transfer!
      source = transaction.source_account
      target = transaction.target_account
      amount = transaction.amount

      lock_accounts(source, target) do
        source.reload
        target.reload

        raise Account::InsufficientFundsError, "Insufficient funds" if target.balance < amount

        source.update!(balance: source.balance + amount)
        target.update!(balance: target.balance - amount)
        Transaction.create_reversal!(transaction)
        transaction.status_reversed!
      end
    end

    def lock_accounts(first_account, second_account)
      ordered = [ first_account, second_account ].sort_by(&:id)
      ordered[0].with_lock do
        ordered[1].with_lock { yield }
      end
    end
  end
end
