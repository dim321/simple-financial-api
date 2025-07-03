require 'rails_helper'

RSpec.describe AccountOperations::AccountStatusService do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, balance: 100.0, status: 'active') }

  subject(:service) { described_class.new(account) }

  describe '#hold' do
    context 'when account is active' do
      it 'changes status to holded' do
        expect { service.hold }.to change { account.reload.status }.from('active').to('holded')
      end

      it 'returns the account' do
        expect(service.hold).to eq(account)
      end
    end

    context 'when account is already holded' do
      before { account.update!(status: 'holded') }

      it 'raises InactiveAccountError' do
        expect { service.hold }.to raise_error(Account::InactiveAccountError, 'Account is not active')
      end
    end

    context 'when account is closed' do
      before { account.update!(status: 'closed') }

      it 'raises InactiveAccountError' do
        expect { service.hold }.to raise_error(Account::InactiveAccountError, 'Account is not active')
      end
    end
  end

  describe '#unhold' do
    context 'when account is holded' do
      before { account.update!(status: 'holded') }

      it 'changes status to active' do
        expect { service.unhold }.to change { account.reload.status }.from('holded').to('active')
      end

      it 'returns the account' do
        expect(service.unhold).to eq(account)
      end
    end

    context 'when account is already active' do
      it 'raises InactiveAccountError' do
        expect { service.unhold }.to raise_error(Account::InactiveAccountError, 'Account is not holded')
      end
    end

    context 'when account is closed' do
      before { account.update!(status: 'closed') }

      it 'raises InactiveAccountError' do
        expect { service.unhold }.to raise_error(Account::InactiveAccountError, 'Account is not holded')
      end
    end
  end

  describe '#close' do
    context 'when account has zero balance' do
      before { account.update!(balance: 0.0) }

      it 'changes status to closed' do
        expect { service.close }.to change { account.reload.status }.from('active').to('closed')
      end

      it 'returns the account' do
        expect(service.close).to eq(account)
      end
    end

    context 'when account has positive balance' do
      it 'raises NonZeroBalanceError' do
        expect { service.close }.to raise_error(Account::NonZeroBalanceError, 'Cannot close account with positive balance')
      end
    end

    context 'when account is holded with zero balance' do
      before do
        account.update!(status: 'holded', balance: 0.0)
      end

      it 'changes status to closed' do
        expect { service.close }.to change { account.reload.status }.from('holded').to('closed')
      end
    end

    context 'when account is already closed' do
      before { account.update!(status: 'closed', balance: 5.0) }

      it 'raises NonZeroBalanceError' do
        expect { service.close }.to raise_error(Account::NonZeroBalanceError, 'Cannot close account with positive balance')
      end
    end
  end

  describe 'status transitions' do
    it 'allows valid status transitions' do
      # active -> holded -> active -> closed (with zero balance)
      expect { service.hold }.to change { account.reload.status }.to('holded')
      expect { service.unhold }.to change { account.reload.status }.to('active')

      # Set balance to zero to allow closing
      account.update!(balance: 0.0)
      expect { service.close }.to change { account.reload.status }.to('closed')
    end

    it 'allows direct transition from holded to closed with zero balance' do
      account.update!(status: 'holded', balance: 0.0)
      expect { service.close }.to change { account.reload.status }.to('closed')
    end
  end

  describe 'concurrent status changes' do
    it 'handles race conditions properly' do
      threads = []
      results = []

      3.times do
        threads << Thread.new do
          service = described_class.new(account)
          begin
            results << service.hold
          rescue Account::InactiveAccountError
            # Expected for subsequent calls
          end
        end
      end

      threads.each(&:join)

      expect(account.reload.status).to eq('holded')
      expect(results.compact.count).to eq(1)
    end
  end

  describe 'edge cases' do
    context 'when trying to close account with very small positive balance' do
      before { account.update!(balance: 0.01) }

      it 'raises NonZeroBalanceError' do
        expect { service.close }.to raise_error(Account::NonZeroBalanceError, 'Cannot close account with positive balance')
      end
    end
  end
end
