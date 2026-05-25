class CurrencyCode
  SUPPORTED = %w[USD EUR].freeze

  class UnsupportedCurrencyError < StandardError; end

  def self.normalize!(value)
    code = value.to_s.strip.upcase
    raise UnsupportedCurrencyError, "Unsupported currency: #{value}" unless SUPPORTED.include?(code)

    code
  end
end
