class Transaction < ApplicationRecord
  belongs_to :source_account, class_name: "Account", optional: true
  belongs_to :target_account, class_name: "Account", optional: true
  belongs_to :original_transaction, class_name: "Transaction", optional: true
  has_one :reversal_transaction, class_name: "Transaction", foreign_key: :original_transaction_id, dependent: :restrict_with_error

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true
  validates :transaction_type, presence: true
  validates :status, presence: true

  enum :transaction_type, {
    deposit: 0,
    withdrawal: 1,
    transfer: 2
  }, prefix: true

  enum :status, {
    pending: 0,
    completed: 1,
    failed: 2,
    reversed: 3
  }, prefix: true

  scope :for_account, ->(account) {
    where("source_account_id = ? OR target_account_id = ?", account.id, account.id)
  }

  scope :recent, -> { order(created_at: :desc) }

  def amount
    MoneyAmount.to_decimal(amount_cents)
  end

  def amount=(value)
    self.amount_cents = MoneyAmount.to_cents(value)
  end

  def self.create_deposit!(account, amount, description: nil)
    create!(
      target_account: account,
      amount_cents: MoneyAmount.to_cents(amount),
      currency: account.currency,
      transaction_type: :deposit,
      status: :completed,
      description: description
    )
  end

  def self.create_withdrawal!(account, amount, description: nil)
    create!(
      source_account: account,
      amount_cents: MoneyAmount.to_cents(amount),
      currency: account.currency,
      transaction_type: :withdrawal,
      status: :completed,
      description: description
    )
  end

  def self.create_transfer!(source_account, target_account, amount, description: nil)
    create!(
      source_account: source_account,
      target_account: target_account,
      amount_cents: MoneyAmount.to_cents(amount),
      currency: source_account.currency,
      transaction_type: :transfer,
      status: :completed,
      description: description
    )
  end

  def self.create_reversal!(original)
    create!(
      source_account: original.target_account,
      target_account: original.source_account,
      amount_cents: original.amount_cents,
      currency: original.currency,
      transaction_type: :transfer,
      status: :completed,
      original_transaction: original,
      description: "Reversal of transaction ##{original.id}"
    )
  end
end
