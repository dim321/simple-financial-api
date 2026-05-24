require 'rails_helper'

RSpec.describe 'Financial API flow', type: :request do
  it 'covers the main usage scenario from README' do
    email = 'flow_user@test.dom'
    password = 'password'

    register_user(email: email, password: password, name: 'John')
    expect(response).to have_http_status(:ok)
    expect(json_response['status']['message']).to eq('Signed up successfully.')

    headers = sign_in_and_return_headers(email: email, password: password)
    expect(response).to have_http_status(:ok)
    expect(headers['Authorization']).to start_with('Bearer ')

    post '/api/v1/accounts',
         params: { account: { currency: 'USD' } },
         headers: headers,
         as: :json
    expect(response).to have_http_status(:created)
    account_number = json_response['data']['account_number']

    get '/api/v1/accounts/balance', headers: headers
    expect(response).to have_http_status(:ok)
    expect(json_response['data']).to include(
      'account_number' => account_number,
      'balance' => '0.0',
      'currency' => 'USD'
    )

    post '/api/v1/accounts/deposit',
         params: { amount: 1000, currency: 'USD' },
         headers: headers,
         as: :json
    expect(response).to have_http_status(:ok)
    expect(json_response['data']['balance']).to eq('1000.0')

    post '/api/v1/accounts/withdraw',
         params: { amount: 75, currency: 'USD' },
         headers: headers,
         as: :json
    expect(response).to have_http_status(:ok)
    expect(json_response['data']['balance']).to eq('925.0')

    recipient = create(
      :user,
      email: 'friend@test.dom',
      password: password,
      password_confirmation: password,
      name: 'Friend'
    )
    create(:account, user: recipient, currency: 'USD', balance: 925.0)

    post '/api/v1/accounts/transfer',
         params: {
           amount: 175,
           currency: 'USD',
           recipient_email: recipient.email
         },
         headers: headers,
         as: :json
    expect(response).to have_http_status(:ok)
    expect(json_response['data']['sender']['balance']).to eq('750.0')
    expect(json_response['data']['recipient']['balance']).to eq('1100.0')

    delete '/api/v1/auth/sign_out', headers: headers
    expect(response).to have_http_status(:ok)
    expect(json_response['status']['message']).to eq('Logged out successfully.')
  end
end
