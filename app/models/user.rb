class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  has_many :accounts, dependent: :destroy
  has_many :transactions, through: :accounts

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  validates :name, presence: true

  def jwt_token
    Warden::JWTAuth::UserEncoder.new.call(self, :user, nil).first
  end

  def deposit(amount, currency = 'USD')
    with_lock do
      account = account_in_currency(currency)
      account.deposit(amount)
      save!
    end
  end

  def withdraw(amount)
    with_lock do
      raise InsufficientFundsError if balance < amount
      self.balance -= amount
      save!
    end
  end

  def transfer(amount, recipient)
    with_lock do
      withdraw(amount)
      recipient.deposit(amount)
    end
  end

  def default_account
    accounts.find_or_create_by(currency: 'USD') do |account|
      account.status = 'active'
    end
  end

  def account_in_currency(currency)
    accounts.find_or_create_by!(currency: currency)
  end

  def balance(currency = 'USD')
    account = accounts.find_by(currency: currency)
    account&.balance || 0
  end

  def total_balance
    accounts.sum(:balance)
  end

  private

  def password_required?
    new_record? || password.present?
  end
end

class InsufficientFundsError < StandardError; end
