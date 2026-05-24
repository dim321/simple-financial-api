module RequestHelpers
  def json_response
    JSON.parse(response.body)
  end

  def auth_headers_for(user)
    {
      'Authorization' => "Bearer #{user.jwt_token}",
      'Content-Type' => 'application/json'
    }
  end

  def sign_in_and_return_headers(email:, password:)
    post '/api/v1/auth/sign_in',
         params: { user: { email: email, password: password } },
         as: :json

    {
      'Authorization' => response.headers['Authorization'],
      'Content-Type' => 'application/json'
    }
  end

  def register_user(email:, password: 'password', name: 'John')
    post '/api/v1/auth',
         params: { user: { email: email, password: password, name: name } },
         as: :json
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
