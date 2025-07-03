require 'rails_helper'

RSpec.describe AccountOperations::WithdrawService do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, balance: 100.0, status: 'active') }
  let(:amount) { 50.0 }
  let(:description) { 'Test withdrawal' }

  subject(:service) { described_class.new(account, amount, description: description) }

  describe '#call' do
    context 'when withdrawal is valid' do
      it 'decreases account balance' do
        expect { service.call }.to change { account.reload.balance }.by(-amount)
      end

      it 'creates a withdrawal transaction' do
        expect { service.call }.to change(Transaction, :count).by(1)
      end

      it 'creates transaction with correct attributes' do
        service.call
        transaction = Transaction.last

        expect(transaction.amount).to eq(amount)
        expect(transaction.transaction_type).to eq('withdrawal')
        expect(transaction.status).to eq('completed')
        expect(transaction.description).to eq(description)
        expect(transaction.source_account).to eq(account)
        expect(transaction.target_account).to be_nil
      end

      it 'returns the account' do
        expect(service.call).to eq(account)
      end
    end

    context 'when amount is zero' do
      let(:amount) { 0 }

      it 'raises InvalidAmountError' do
        expect { service.call }.to raise_error(Account::InvalidAmountError, 'Amount must be positive')
      end
    end

    context 'when amount is negative' do
      let(:amount) { -10 }

      it 'raises InvalidAmountError' do
        expect { service.call }.to raise_error(Account::InvalidAmountError, 'Amount must be positive')
      end
    end

    context 'when account has insufficient funds' do
      let(:amount) { 150.0 }

      it 'raises InsufficientFundsError' do
        expect { service.call }.to raise_error(Account::InsufficientFundsError, 'Insufficient funds')
      end
    end

    context 'when account is not active' do
      before { account.update!(status: 'holded') }

      it 'raises InactiveAccountError' do
        expect { service.call }.to raise_error(Account::InactiveAccountError, 'Account is not active')
      end
    end

    context 'when account is closed' do
      before { account.update!(status: 'closed') }

      it 'raises InactiveAccountError' do
        expect { service.call }.to raise_error(Account::InactiveAccountError, 'Account is not active')
      end
    end

    context 'when description is nil' do
      let(:description) { nil }

      it 'creates transaction without description' do
        service.call
        transaction = Transaction.last

        expect(transaction.description).to be_nil
      end
    end

    context 'when withdrawing exact balance' do
      let(:amount) { 100.0 }

      it 'allows withdrawal and sets balance to zero' do
        expect { service.call }.to change { account.reload.balance }.to(0.0)
      end
    end

    context 'when multiple withdrawals happen concurrently' do
      it 'prevents race conditions' do
        threads = []
        errors = []

        3.times do
          threads << Thread.new do
            service = described_class.new(account, 40.0)
            begin
              service.call
            rescue Account::InsufficientFundsError => e
              errors << e
            end
          end
        end

        threads.each(&:join)

        # Only 2 withdrawals should succeed (100 - 2*40 = 20 remaining)
        expect(account.reload.balance).to eq(20.0)
        expect(errors.count).to eq(1)
      end
    end

    context 'when database transaction fails' do
      before do
        allow(Transaction).to receive(:create_withdrawal!).and_raise(ActiveRecord::RecordInvalid.new())
      end

      it 'rolls back balance changes' do
        expect {
          begin
            service.call
          rescue ActiveRecord::RecordInvalid
            # Expected error
          end
        }.not_to change { account.reload.balance }
      end
    end
  end
end
