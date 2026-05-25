class AccountSerializer
  include JSONAPI::Serializer

  attributes :id, :account_number, :balance, :currency, :status, :created_at, :updated_at

  attribute :user do |account|
    {
      id: account.user.id
    }
  end
end
