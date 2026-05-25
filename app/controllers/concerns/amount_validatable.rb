module AmountValidatable
  extend ActiveSupport::Concern

  private

  def parse_amount!(value)
    raise Account::InvalidAmountError, "Amount is required or invalid" if value.blank?

    amount = BigDecimal(value.to_s)
    raise Account::InvalidAmountError, "Amount must be positive" if amount <= 0

    amount
  rescue ArgumentError, TypeError
    raise Account::InvalidAmountError, "Amount is required or invalid"
  end
end
