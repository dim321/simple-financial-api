class AccountSerializer
  include JSONAPI::Serializer

  attributes :id, :account_number, :currency, :status, :created_at, :updated_at

  attribute :balance do |account|
    MoneyAmount.to_api_s(account.balance_cents)
  end

  attribute :user do |account|
    {
      id: account.user.id
    }
  end
end
