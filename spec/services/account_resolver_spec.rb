require "rails_helper"

RSpec.describe AccountResolver do
  let(:user) { create(:user) }
  let!(:usd_account) { create(:account, user: user, currency: "USD", balance: 100) }
  let!(:eur_account) { create(:account, user: user, currency: "EUR", balance: 50) }

  subject(:resolver) { described_class.new(user) }

  describe "#resolve" do
    it "finds account by currency" do
      expect(resolver.resolve(currency: "EUR")).to eq(eur_account)
    end

    it "finds account by account_number" do
      expect(resolver.resolve(account_number: eur_account.account_number)).to eq(eur_account)
    end

    it "raises when currency account does not exist" do
      expect { resolver.resolve(currency: "GBP") }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#resolve_recipient" do
    let(:recipient) { create(:user) }
    let!(:recipient_account) { create(:account, user: recipient, currency: "USD") }

    it "returns recipient account in the requested currency" do
      account = resolver.resolve_recipient(email: recipient.email, currency: "USD")
      expect(account).to eq(recipient_account)
    end

    it "returns nil when recipient is unknown" do
      expect(resolver.resolve_recipient(email: "missing@test.dom", currency: "USD")).to be_nil
    end
  end
end
