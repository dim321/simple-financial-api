class UserSerializer
  include JSONAPI::Serializer

  attributes :id, :email

  # attribute :accounts do |object|
  #   object.accounts.map do |account|
  #     {
  #       id: account.id,
  #       currency: account.currency,
  #       balance: account.balance,
  #       status: account.status
  #     }
  #   end
  # end

  # attribute :total_balance do |object|
  #   object.total_balance
  # end
end
