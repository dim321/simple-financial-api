require "rails_helper"

RSpec.describe AccountOperations::ReverseService do
  let(:sender) { create(:user, email: "sender_reverse@test.dom") }
  let(:recipient) { create(:user, email: "recipient_reverse@test.dom") }
  let(:source_account) { create(:account, user: sender, balance: 500.0, status: "active") }
  let(:target_account) { create(:account, user: recipient, balance: 0.0, status: "active") }

  describe "#call" do
    let!(:transfer) do
      source_account.transfer(100.0, target_account)
      Transaction.last
    end

    it "reverses a completed transfer once" do
      expect {
        described_class.new(transfer).call
      }.to change(Transaction, :count).by(1)

      reversal = transfer.reload.reversal_transaction

      expect(transfer.reload).to be_status_reversed
      expect(reversal.original_transaction).to eq(transfer)
      expect(source_account.reload.balance).to eq(500.0)
      expect(target_account.reload.balance).to eq(0.0)
    end

    it "allows only one concurrent reverse for the same transfer" do
      errors = Queue.new
      original_create_reversal = Transaction.method(:create_reversal!)

      allow(Transaction).to receive(:create_reversal!) do |original|
        sleep 0.05
        original_create_reversal.call(original)
      end

      threads = 2.times.map do
        Thread.new do
          described_class.new(Transaction.find(transfer.id)).call
        rescue described_class::NotReversibleError => e
          errors << e
        end
      end

      threads.each(&:join)

      expect(errors.size).to eq(1)
      expect(Transaction.where(description: "Reversal of transaction ##{transfer.id}").count).to eq(1)
      expect(transfer.reload).to be_status_reversed
      expect(transfer.reversal_transaction).to be_present
      expect(source_account.reload.balance).to eq(500.0)
      expect(target_account.reload.balance).to eq(0.0)
    end
  end
end
