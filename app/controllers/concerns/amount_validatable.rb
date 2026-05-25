module AmountValidatable
  extend ActiveSupport::Concern

  private

  def parse_amount!(value)
    raise Account::InvalidAmountError, "Amount is required or invalid" if value.blank?

    amount = MoneyAmount.to_decimal(MoneyAmount.to_cents(value))
    raise Account::InvalidAmountError, "Amount must be positive" if amount <= 0

    amount
  rescue ArgumentError, TypeError, MoneyAmount::InvalidAmountError
    raise Account::InvalidAmountError, "Amount is required or invalid"
  end
end
