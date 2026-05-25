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
        'id' => sender.id
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
      create(:account, user: sender, currency: 'EUR', balance: 50.0)
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

    it 'returns the balance for the account selected by currency' do
      get '/api/v1/accounts/balance', params: { currency: 'EUR' }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(
        'balance' => '50.0',
        'currency' => 'EUR'
      )
    end
  end

  describe 'GET /api/v1/accounts/balance without a default account' do
    it 'returns not found without creating an account' do
      expect {
        get '/api/v1/accounts/balance', headers: headers
      }.not_to change(Account, :count)

      expect(response).to have_http_status(:not_found)
      expect(json_response['status']).to eq(
        'code' => 404,
        'message' => 'Account not found.'
      )
    end
  end

  describe 'GET /api/v1/accounts' do
    before do
      create(:account, user: sender, currency: 'USD', balance: 100)
      create(:account, user: sender, currency: 'EUR', balance: 50)
    end

    it 'returns all accounts for the authenticated user' do
      get '/api/v1/accounts', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(2)
      expect(json_response['data'].map { |row| row['currency'] }).to contain_exactly('USD', 'EUR')
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

    it 'deposits funds to the account selected by currency' do
      create(:account, user: sender, currency: 'EUR', balance: 0)

      post '/api/v1/accounts/deposit',
           params: { amount: 250, currency: 'EUR' },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['balance']).to eq('250.0')
      expect(json_response['data']['currency']).to eq('EUR')
    end

    it 'returns an error when amount is missing' do
      post '/api/v1/accounts/deposit',
           params: { currency: 'USD' },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['status']['message']).to eq('Amount is required or invalid')
    end

    it 'returns an error when amount has more than two decimal places' do
      post '/api/v1/accounts/deposit',
           params: { amount: '10.999', currency: 'USD' },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['status']['message']).to eq('Amount is required or invalid')
    end

    it 'does not repeat a deposit when the same Idempotency-Key is reused' do
      idempotent_headers = headers.merge('Idempotency-Key' => 'deposit-key-1')

      expect {
        post '/api/v1/accounts/deposit',
             params: { amount: 100, currency: 'USD' },
             headers: idempotent_headers,
             as: :json
      }.to change(Transaction, :count).by(1)

      expect {
        post '/api/v1/accounts/deposit',
             params: { amount: 100, currency: 'USD' },
             headers: idempotent_headers,
             as: :json
      }.not_to change(Transaction, :count)

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['balance']).to eq('100.0')
      expect(sender.accounts.find_by!(currency: 'USD').balance).to eq(100.0)
    end

    it 'returns a conflict when the same Idempotency-Key is reused with a different body' do
      idempotent_headers = headers.merge('Idempotency-Key' => 'deposit-key-2')

      post '/api/v1/accounts/deposit',
           params: { amount: 100, currency: 'USD' },
           headers: idempotent_headers,
           as: :json

      expect {
        post '/api/v1/accounts/deposit',
             params: { amount: 200, currency: 'USD' },
             headers: idempotent_headers,
             as: :json
      }.not_to change(Transaction, :count)

      expect(response).to have_http_status(:conflict)
      expect(json_response['status']).to eq(
        'code' => 409,
        'message' => 'Idempotency-Key has already been used with a different request.'
      )
      expect(sender.accounts.find_by!(currency: 'USD').balance).to eq(100.0)
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
      expect(json_response['data']['sender']['user']).to eq('id' => sender.id)
      expect(json_response['data']['recipient']['user']).to eq('id' => recipient.id)
    end

    it 'returns an error when recipient email is missing' do
      post '/api/v1/accounts/transfer',
           params: { amount: 10, currency: 'USD' },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['status']['message']).to eq('Recipient email is required')
    end

    it 'returns an error for unsupported currency' do
      post '/api/v1/accounts/transfer',
           params: {
             amount: 10,
             currency: 'GBP',
             recipient_email: recipient.email
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['status']['message']).to include('Unsupported currency')
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
