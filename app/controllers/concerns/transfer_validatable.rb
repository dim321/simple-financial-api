module TransferValidatable
  extend ActiveSupport::Concern

  private

  def validate_transfer_params!
    email = params[:recipient_email].to_s.strip
    raise Account::InvalidAccountError, "Recipient email is required" if email.blank?
    raise Account::InvalidAccountError, "Recipient email is invalid" unless email.match?(URI::MailTo::EMAIL_REGEXP)

    normalize_currency_param!(params[:currency]) if params[:currency].present?
  end

  def normalize_currency_param!(value)
    CurrencyCode.normalize!(value)
  rescue CurrencyCode::UnsupportedCurrencyError => e
    raise Account::InvalidCurrencyError, e.message
  end
end
