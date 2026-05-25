class MoneyAmount
  SCALE = 2
  CENTS_PER_UNIT = 100
  DECIMAL_FORMAT = /\A-?\d+(\.\d{1,2})?\z/

  class InvalidAmountError < ArgumentError; end

  def self.to_cents(value)
    case value
    when Integer
      value * CENTS_PER_UNIT
    when BigDecimal
      decimal_to_cents(value)
    when Float
      to_cents(value.to_s)
    else
      string_to_cents(value)
    end
  end

  def self.to_decimal(cents)
    BigDecimal(cents.to_i) / CENTS_PER_UNIT
  end

  def self.to_api_s(cents)
    decimal = to_decimal(cents)
    decimal.frac.zero? ? format("%.1f", decimal) : decimal.to_s("F")
  end

  def self.string_to_cents(value)
    string = value.to_s.strip
    raise InvalidAmountError if string.blank? || !string.match?(DECIMAL_FORMAT)

    decimal_to_cents(BigDecimal(string))
  end
  private_class_method :string_to_cents

  def self.decimal_to_cents(value)
    cents = value * CENTS_PER_UNIT
    raise InvalidAmountError unless cents.frac.zero?

    cents.to_i
  end
  private_class_method :decimal_to_cents
end
