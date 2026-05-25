class Transaction < ApplicationRecord
  belongs_to :source_account, class_name: "Account", optional: true
  belongs_to :target_account, class_name: "Account", optional: true

  validates :amount, presence: true
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

  def self.create_deposit!(account, amount, description: nil)
    create!(
      target_account: account,
      amount: amount,
      currency: account.currency,
      transaction_type: :deposit,
      status: :completed,
      description: description
    )
  end

  def self.create_withdrawal!(account, amount, description: nil)
    create!(
      source_account: account,
      amount: amount,
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
      amount: amount,
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
      amount: original.amount,
      currency: original.currency,
      transaction_type: :transfer,
      status: :completed,
      description: "Reversal of transaction ##{original.id}"
    )
  end
end
