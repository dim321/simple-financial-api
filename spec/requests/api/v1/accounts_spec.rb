require 'rails_helper'

RSpec.describe 'Api::V1::Accounts', type: :request do
  let(:password) { 'password' }
  let(:sender) do
    create(:user, email: 'sender@test.dom', password: password, password_confirmation: password, name: 'Sender')
  end
  let(:headers) { auth_headers_for(sender) }

  describe 'POST /api/v1/accounts' do
    it 'creates an account for the authenticated user' do
      post '/api/v1/accounts',
           params: { account: { currency: 'USD' } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq(
        'code' => 201,
        'message' => 'Account created successfully.'
      )
      expect(json_response['data']).to include(
        'balance' => '0.0',
        'currency' => 'USD',
        'status' => 'active'
      )
      expect(json_response['data']['account_number']).to be_present
      expect(json_response['data']['user']).to eq(
        'id' => sender.id,
        'email' => sender.email
      )
    end

    it 'requires authentication' do
      post '/api/v1/accounts',
           params: { account: { currency: 'USD' } },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/accounts/balance' do
    before do
      create(:account, user: sender, currency: 'USD', balance: 925.0)
    end

    it 'returns the balance of the default account' do
      get '/api/v1/accounts/balance', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq(
        'code' => 200,
        'message' => 'Balance.'
      )
      expect(json_response['data']).to include(
        'balance' => '925.0',
        'currency' => 'USD'
      )
      expect(json_response['data']['account_number']).to be_present
      expect(json_response['data']['updated_at']).to be_present
    end
  end

  describe 'POST /api/v1/accounts/deposit' do
    before do
      create(:account, user: sender, currency: 'USD', balance: 0)
    end

    it 'deposits funds to the account' do
      post '/api/v1/accounts/deposit',
           params: { amount: 1000, currency: 'USD' },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq(
        'code' => 200,
        'message' => 'Deposit successful.'
      )
      expect(json_response['data']['balance']).to eq('1000.0')
      expect(json_response['data']['currency']).to eq('USD')
    end
  end

  describe 'POST /api/v1/accounts/withdraw' do
    before do
      create(:account, user: sender, currency: 'USD', balance: 1000.0)
    end

    it 'withdraws funds from the account' do
      post '/api/v1/accounts/withdraw',
           params: { amount: 75, currency: 'USD' },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq(
        'code' => 200,
        'message' => 'Withdrawal successful.'
      )
      expect(json_response['data']['balance']).to eq('925.0')
    end
  end

  describe 'POST /api/v1/accounts/transfer' do
    let(:recipient) do
      create(:user, email: 'recipient@test.dom', password: password, password_confirmation: password, name: 'Recipient')
    end

    before do
      create(:account, user: recipient, currency: 'USD', balance: 0)
      create(:account, user: sender, currency: 'USD', balance: 925.0)
    end

    it 'transfers funds to another user' do
      post '/api/v1/accounts/transfer',
           params: {
             amount: 175,
             currency: 'USD',
             recipient_email: recipient.email
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq(
        'code' => 200,
        'message' => 'Transfer successful.'
      )
      expect(json_response['data']['sender']['balance']).to eq('750.0')
      expect(json_response['data']['recipient']['balance']).to eq('175.0')
      expect(json_response['data']['sender']['user']['email']).to eq(sender.email)
      expect(json_response['data']['recipient']['user']['email']).to eq(recipient.email)
    end

    it 'returns an error for an unknown recipient' do
      post '/api/v1/accounts/transfer',
           params: {
             amount: 175,
             currency: 'USD',
             recipient_email: 'unknown_test@test.dom'
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['status']).to eq(
        'code' => 422,
        'message' => 'Target account unknown'
      )
    end
  end
end
