class AccountResolver
  def initialize(user)
    @user = user
  end

  def resolve(account_id: nil, currency: nil, account_number: nil)
    if account_number.present?
      @user.accounts.find_by!(account_number: account_number)
    elsif account_id.present?
      @user.accounts.find(account_id)
    elsif currency.present?
      @user.accounts.find_by!(currency: currency.to_s.upcase)
    else
      @user.default_account
    end
  end

  def resolve_recipient(email:, currency: nil)
    recipient = User.find_by(email: email)
    return nil if recipient.nil?

    currency = (currency.presence || "USD").to_s.upcase
    recipient.accounts.find_by(currency: currency)
  end
end
