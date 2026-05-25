require 'rails_helper'

RSpec.describe AccountOperations::TransferService do
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:source_account) { create(:account, user: user1, balance: 100.0, status: 'active') }
  let(:target_account) { create(:account, user: user2, balance: 50.0, status: 'active') }
  let(:amount) { 30.0 }
  let(:description) { 'Test transfer' }

  subject(:service) { described_class.new(source_account, target_account, amount, description: description) }

  describe '#call' do
    context 'when transfer is valid' do
      it 'decreases source account balance' do
        expect { service.call }.to change { source_account.reload.balance }.by(-amount)
      end

      it 'increases target account balance' do
        expect { service.call }.to change { target_account.reload.balance }.by(amount)
      end

      it 'creates one transaction' do
        expect { service.call }.to change(Transaction, :count).by(1)
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

    context 'when source account has insufficient funds' do
      let(:amount) { 150.0 }

      it 'raises InsufficientFundsError' do
        expect { service.call }.to raise_error(Account::InsufficientFundsError, 'Insufficient funds')
      end

      it 'does not change any account balances' do
        expect {
          begin
            service.call
          rescue Account::InsufficientFundsError
            # Expected error
          end
        }.not_to change { [source_account.reload.balance, target_account.reload.balance] }
      end
    end

    context 'when source account is not active' do
      let(:source_account) { create(:account, user: user1, balance: 100.0, status: 'holded') }

      it 'raises InactiveAccountError' do
        expect { service.call }.to raise_error(Account::InactiveAccountError, 'Source account is not active')
      end
    end

    context 'when target account is non-existent' do
      let(:target_account) { nil }

      it 'raises InactiveAccountError' do
        expect { service.call }.to raise_error(Account::InvalidAccountError, 'Target account unknown')
      end
    end

    context 'when transferring to the same account' do
      let(:target_account) { source_account }

      it 'raises SameAccountError' do
        expect { service.call }.to raise_error(Account::SelfTransferError, 'Cannot transfer to the same account')
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

    context 'when transferring exact balance' do
      let(:amount) { 100.0 }

      it 'allows transfer and sets source balance to zero' do
        expect { service.call }.to change { source_account.reload.balance }.to(0.0)
      end

      it 'increases target balance correctly' do
        expect { service.call }.to change { target_account.reload.balance }.to(150.0)
      end
    end

    context 'when two large transfers happen concurrently' do
      it 'allows only one transfer when balance covers a single transfer' do
        threads = []
        errors = []

        2.times do
          threads << Thread.new do
            transfer_service = described_class.new(source_account, target_account, 80.0)
            begin
              transfer_service.call
            rescue Account::InsufficientFundsError => e
              errors << e
            end
          end
        end

        threads.each(&:join)

        expect(source_account.reload.balance).to eq(20.0)
        expect(target_account.reload.balance).to eq(130.0)
        expect(errors.count).to eq(1)
      end
    end

    context 'when multiple transfers happen concurrently' do
      it 'prevents race conditions' do
        threads = []
        errors = []

        4.times do
          threads << Thread.new do
            service = described_class.new(source_account, target_account, 30.0)
            begin
              service.call
            rescue Account::InsufficientFundsError => e
              errors << e
            end
          end
        end

        threads.each(&:join)

        # Only 3 transfers should succeed (100 - 3*30 = 10 remaining)
        expect(source_account.reload.balance).to eq(10.0)
        expect(target_account.reload.balance).to eq(140.0) # 50 + 3*30
        expect(errors.count).to eq(1)
      end
    end

    context 'when database transaction fails' do
      before do
        allow(Transaction).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(Transaction.new))
      end

      it 'rolls back all changes' do
        expect {
          begin
            service.call
          rescue ActiveRecord::RecordInvalid
            # Expected error
          end
        }.not_to change { [source_account.reload.balance, target_account.reload.balance] }
      end
    end
  end
end
