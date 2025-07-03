require 'rails_helper'

RSpec.describe AccountOperations::DepositService do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, balance: 100.0, status: 'active') }
  let(:amount) { 50.0 }
  let(:description) { 'Test deposit' }

  subject(:service) { described_class.new(account, amount, description: description) }

  describe '#call' do
    context 'when deposit is valid' do
      it 'increases account balance' do
        expect { service.call }.to change { account.reload.balance }.by(amount)
      end

      it 'creates a deposit transaction' do
        expect { service.call }.to change(Transaction, :count).by(1)
      end

      it 'creates transaction with correct attributes' do
        service.call
        transaction = Transaction.last

        expect(transaction.amount).to eq(amount)
        expect(transaction.transaction_type).to eq('deposit')
        expect(transaction.description).to eq(description)
        expect(transaction.target_account).to eq(account)
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

    context 'when multiple deposits happen concurrently' do
      it 'handles race conditions properly' do
        Transaction.delete_all
        threads = []
        results = []

        5.times do
          threads << Thread.new do
            service = described_class.new(account, 10.0)
            results << service.call
          end
        end

        threads.each(&:join)

        expect(account.reload.balance).to eq(150.0) # 100 + 5 * 10
        expect(Transaction.count).to eq(5)
      end
    end
  end
end
