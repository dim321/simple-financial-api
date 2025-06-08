class Account < ApplicationRecord
  class InsufficientFundsError < StandardError; end
  class InvalidAmountError < StandardError; end
  class InactiveAccountError < StandardError; end
  class TargetAccountInactiveError < StandardError; end
  class SelfTransferError < StandardError; end
  class NonZeroBalanceError < StandardError; end
  class DifferentCurrencyError < StandardError; end

  belongs_to :user
  has_many :transactions, dependent: :restrict_with_error

  validates :account_number, presence: true, uniqueness: true
  validates :currency, presence: true
  validates :status, presence: true
  validates :balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, uniqueness: { scope: :user_id, message: "account in this currency already exists" }

  enum :status, {
    active: 'active',
    holded: 'holded',
    closed: 'closed'
  }, default: 'active'

  before_validation :generate_account_number, on: :create
  before_validation :set_default_currency, on: :create

  def transactions
    Transaction.for_account(self).recent
  end

  def deposit(amount)
    raise InvalidAmountError, 'Amount must be positive' if amount <= 0
    raise InactiveAccountError, 'Account is not active' unless active?

    with_lock do
      update!(balance: balance + amount)
      Transaction.create_deposit!(self, amount)
    end
  end

  def withdraw(amount)
    raise InvalidAmountError, 'Amount must be positive' if amount <= 0
    raise InactiveAccountError, 'Account is not active' unless active?
    raise InsufficientFundsError, 'Insufficient funds' if balance < amount

    with_lock do
      update!(balance: balance - amount)
      Transaction.create_withdrawal!(self, amount)
    end
  end

  def transfer(amount, target_account, description: nil)
    raise InvalidAmountError, 'Amount must be positive' if amount <= 0
    raise InactiveAccountError, 'Account is not active' unless active?
    raise TargetAccountInactiveError, 'Target account is not active' unless target_account.active?
    raise InsufficientFundsError, 'Insufficient funds' if balance < amount
    raise SelfTransferError, 'Cannot transfer to the same account' if id == target_account.id
    raise DifferentCurrencyError, 'Cannot transfer between different currencies' if currency != target_account.currency

    with_lock do
      Transaction.create_transfer!(self, target_account, amount, description: description)
      self.update!(balance: balance - amount)
      target_account.update!(balance: target_account.balance + amount)
    end
  end

  def hold_account
    raise InactiveAccountError, 'Account is not active' unless active?
    update!(status: :holded)
  end

  def unhold_account
    raise InactiveAccountError, 'Account is not holded' unless holded?
    update!(status: :active)
  end

  def close_account
    raise InactiveAccountError, 'Account is not active' unless active?
    raise NonZeroBalanceError, 'Cannot close account with positive balance' if balance.positive?

    update!(status: :closed)
  end

  private

  def generate_account_number
    return if account_number.present?

    loop do
      self.account_number = format('%020d', rand(10**20))
      break unless self.class.exists?(account_number: account_number)
    end
  end

  def set_default_currency
    self.currency ||= 'USD'
  end
end
