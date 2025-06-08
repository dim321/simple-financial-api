class TransactionSerializer
  include JSONAPI::Serializer

  attributes :id, :amount, :currency, :transaction_type, :status, :description, :created_at

  attribute :source_account do |transaction|
    if transaction.source_account
      {
        id: transaction.source_account.id,
        account_number: transaction.source_account.account_number
      }
    end
  end

  attribute :target_account do |transaction|
    if transaction.target_account
      {
        id: transaction.target_account.id,
        account_number: transaction.target_account.account_number
      }
    end
  end
end
