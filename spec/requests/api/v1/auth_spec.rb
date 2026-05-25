require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  describe 'POST /api/v1/auth' do
    it 'registers a new user' do
      register_user(email: 'newuser@test.dom', password: 'password', name: 'John')

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq(
        'code' => 200,
        'message' => 'Signed up successfully.'
      )
      expect(json_response['data']).to include(
        'email' => 'newuser@test.dom',
        'name' => 'John'
      )
      expect(json_response['data']['id']).to be_present
    end

    it 'returns validation errors for invalid registration data' do
      register_user(email: 'invalid-email', password: '123', name: '')

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['status']['message']).to include("User couldn't be created successfully")
    end
  end

  describe 'POST /api/v1/auth/sign_in' do
    let!(:user) do
      create(:user, email: 'test@test.dom', password: 'password', password_confirmation: 'password', name: 'John')
    end

    it 'signs in and returns a JWT token in the Authorization header' do
      post '/api/v1/auth/sign_in',
           params: { user: { email: user.email, password: 'password' } },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers['Authorization']).to start_with('Bearer ')
      expect(json_response['status']).to eq(
        'code' => 200,
        'message' => 'Logged in successfully.'
      )
      expect(json_response['data']).to include(
        'id' => user.id,
        'email' => user.email,
        'name' => 'John'
      )
    end

    it 'returns unauthorized for invalid credentials' do
      post '/api/v1/auth/sign_in',
           params: { user: { email: user.email, password: 'wrong-password' } },
           as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json_response['error']).to eq('Invalid Email or password.')
    end
  end

  describe 'DELETE /api/v1/auth/sign_out' do
    let!(:user) { create(:user) }
    let(:headers) { auth_headers_for(user) }

    it 'logs out an authenticated user' do
      delete '/api/v1/auth/sign_out', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq(
        'code' => 200,
        'message' => 'Logged out successfully.'
      )
    end

    it 'requires authentication' do
      delete '/api/v1/auth/sign_out'

      expect(response).to have_http_status(:unauthorized)
      expect(json_response['status']['message']).to eq('Unauthorized. Please authenticate to access this resource.')
    end

    it 'rejects requests with a revoked token after logout' do
      delete '/api/v1/auth/sign_out', headers: headers
      expect(response).to have_http_status(:ok)

      get '/api/v1/accounts/balance', headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
