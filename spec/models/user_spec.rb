require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { create(:user) }

  describe 'associations' do
    it { should have_many(:accounts).dependent(:destroy) }
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes validatable' do
      expect(User.devise_modules).to include(:validatable)
    end

    it 'includes jwt_authenticatable' do
      expect(User.devise_modules).to include(:jwt_authenticatable)
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:password) }
    it { should validate_length_of(:password).is_at_least(6) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:user)).to be_valid
    end

    it 'has a valid factory with account' do
      expect(build(:user, :with_account)).to be_valid
    end
  end

  describe 'email format' do
    it 'accepts valid email formats' do
      valid_emails = [
        'user@example.com',
        'user.name@example.com',
        'user+tag@example.co.uk',
        'user123@example-domain.com'
      ]

      valid_emails.each do |email|
        user = build(:user, email: email)
        expect(user).to be_valid
      end
    end

    it 'rejects invalid email formats' do
      invalid_emails = [
        'invalid-email',
        '@example.com',
        'user@',
        'user@.com'
      ]

      invalid_emails.each do |email|
        user = build(:user, email: email)
        user.valid?
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('is invalid')
      end
    end
  end

  describe 'password validation' do
    it 'requires password confirmation to match' do
      user = build(:user, password: 'password123', password_confirmation: 'different')
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to include("doesn't match Password")
    end

    it 'requires minimum password length' do
      user = build(:user, password: '12345', password_confirmation: '12345')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include('is too short (minimum is 6 characters)')
    end
  end

  describe 'default' do
    describe 'account' do
      it 'creates an account for the user' do
        expect {
          create(:user).default_account
        }.to change(Account, :count).by(1)
      end

      it 'creates account with correct user association' do
        user = create(:user)
        expect(user.default_account).to be_present
        expect(user.default_account.user).to eq(user)
      end

      it 'creates account with default values' do
        user = create(:user)
        account = user.default_account

        expect(account.balance).to eq(0.0)
        expect(account.status).to eq('active')
      end
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user) }

    describe '#account' do
      it 'returns the associated account' do
        expect(user.default_account).to be_an_instance_of(Account)
        expect(user.default_account.user).to eq(user)
      end
    end

    describe '#account_status' do
      it 'returns the account status' do
        user.default_account.holded!
        expect(user.default_account.status).to eq('holded')
      end
    end
  end

  describe 'database constraints' do
    it 'enforces email uniqueness' do
      create(:user, email: 'test@example.com')

      expect {
        create(:user, email: 'test@example.com')
      }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Email has already been taken')
    end

    it 'enforces email presence' do
      expect {
        create(:user, email: nil)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
