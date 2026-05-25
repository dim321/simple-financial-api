require "rails_helper"

RSpec.describe "Api::V1::Transactions", type: :request do
  let(:password) { "password123" }
  let(:user) do
    create(:user, email: "owner@test.dom", password: password, password_confirmation: password, name: "Owner")
  end
  let(:headers) { auth_headers_for(user) }
  let!(:account) { create(:account, user: user, currency: "USD", balance: 500.0) }
  let(:recipient) do
    create(:user, email: "peer@test.dom", password: password, password_confirmation: password, name: "Peer")
  end
  let!(:recipient_account) { create(:account, user: recipient, currency: "USD", balance: 0) }

  describe "GET /api/v1/accounts/:account_id/transactions" do
    before do
      account.transfer(100.0, recipient_account)
    end

    it "returns ledger entries for the account" do
      get "/api/v1/accounts/#{account.id}/transactions", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(1)
      expect(json_response["data"].first["transaction_type"]).to eq("transfer")
    end
  end

  describe "POST /api/v1/accounts/:account_id/transactions/:id/reverse" do
    let!(:transfer) do
      account.transfer(100.0, recipient_account)
      Transaction.last
    end

    it "reverses a completed transfer" do
      post "/api/v1/accounts/#{account.id}/transactions/#{transfer.id}/reverse", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]["status"]).to eq("reversed")
      expect(account.reload.balance).to eq(500.0)
      expect(recipient_account.reload.balance).to eq(0.0)
    end
  end
end
