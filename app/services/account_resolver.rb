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
      code = normalize_currency!(currency)
      @user.accounts.find_by!(currency: code)
    else
      @user.default_account
    end
  end

  def resolve_recipient(email:, currency: nil)
    recipient = User.find_by(email: email)
    return nil if recipient.nil?

    code = currency.present? ? normalize_currency!(currency) : "USD"
    recipient.accounts.find_by(currency: code)
  end

  private

  def normalize_currency!(currency)
    CurrencyCode.normalize!(currency)
  rescue CurrencyCode::UnsupportedCurrencyError => e
    raise Account::InvalidCurrencyError, e.message
  end
end
