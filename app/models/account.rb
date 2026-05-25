class Account < ApplicationRecord
  class InsufficientFundsError < StandardError; end
  class InvalidAmountError < StandardError; end
  class InactiveAccountError < StandardError; end
  class SelfTransferError < StandardError; end
  class NonZeroBalanceError < StandardError; end
  class DifferentCurrencyError < StandardError; end
  class InvalidAccountError < StandardError; end

  belongs_to :user
  has_many :outgoing_transactions, class_name: "Transaction", foreign_key: :source_account_id, dependent: :restrict_with_error
  has_many :incoming_transactions, class_name: "Transaction", foreign_key: :target_account_id, dependent: :restrict_with_error

  validates :account_number, presence: true, uniqueness: true
  validates :currency, presence: true
  validates :status, presence: true
  validates :balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, uniqueness: { scope: :user_id, message: "account in this currency already exists" }

  enum :status, {
    active: "active",
    holded: "holded",
    closed: "closed"
  }, default: "active"

  before_validation :generate_account_number, on: :create
  before_validation :set_default_currency, on: :create

  def ledger_entries
    Transaction.for_account(self).recent
  end

  def deposit(amount, description: nil)
    AccountOperations::DepositService.new(self, amount, description: description).call
  end

  def withdraw(amount, description: nil)
    AccountOperations::WithdrawService.new(self, amount, description: description).call
  end

  def transfer(amount, target_account, description: nil)
    AccountOperations::TransferService.new(self, target_account, amount, description: description).call
  end

  def hold_account
    AccountOperations::AccountStatusService.new(self).hold
  end

  def unhold_account
    AccountOperations::AccountStatusService.new(self).unhold
  end

  def close_account
    AccountOperations::AccountStatusService.new(self).close
  end

  private

  def generate_account_number
    return if account_number.present?

    loop do
      self.account_number = format("%020d", rand(10**20))
      break unless self.class.exists?(account_number: account_number)
    end
  end

  def set_default_currency
    self.currency ||= "USD"
  end
end
