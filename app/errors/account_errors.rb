class Account
class AccountError < StandardError; end

class InactiveAccountError < AccountError; end
class TargetAccountInactiveError < AccountError; end
class InvalidAmountError < AccountError; end
class InsufficientFundsError < AccountError; end
class SelfTransferError < AccountError; end
class DifferentCurrencyError < AccountError; end
class NonZeroBalanceError < AccountError; end
end
