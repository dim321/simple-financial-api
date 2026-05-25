module CurrencyNormalizable
  extend ActiveSupport::Concern

  private

  def normalize_optional_currency!(value)
    return if value.blank?

    CurrencyCode.normalize!(value)
  rescue CurrencyCode::UnsupportedCurrencyError => e
    raise Account::InvalidCurrencyError, e.message
  end
end
