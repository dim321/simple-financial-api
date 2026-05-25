class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  has_many :accounts, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?
  validates :name, presence: true

  def jwt_token
    Warden::JWTAuth::UserEncoder.new.call(self, :user, nil).first
  end

  def default_account
    accounts.find_or_create_by(currency: "USD") do |account|
      account.status = "active"
    end
  end

  def account_in_currency(currency)
    accounts.find_by(currency: currency.to_s.upcase)
  end

  private

  def password_required?
    new_record? || password.present?
  end
end
