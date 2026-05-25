class BalanceSerializer
  include JSONAPI::Serializer

  attributes :account_number, :currency, :updated_at

  attribute :balance do |account|
    MoneyAmount.to_api_s(account.balance_cents)
  end
end
