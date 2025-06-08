class BalanceSerializer
  include JSONAPI::Serializer

  attributes :account_number, :balance, :currency, :updated_at
end
