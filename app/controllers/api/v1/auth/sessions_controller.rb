module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        include RackSessionsFix
        include AuthenticationErrors
        respond_to :json
        skip_before_action :authenticate_user_from_token!, only: %i[create]

        private

        def respond_with(resource, _opts = {})
          if resource.persisted?
            render json: {
              status: {
                code: 200,
                message: 'Logged in successfully.'
              },
              data: UserSerializer.new(resource).serializable_hash[:data][:attributes]
            }
          else
            render json: {
              status: {
                code: 401,
                message: 'Invalid email or password.'
              }
            }, status: :unauthorized
          end
        end

        def respond_to_on_destroy
          if request.headers['Authorization'].present?
            begin
              jwt_payload = JWT.decode(request.headers['Authorization'].split(' ').last, Rails.application.credentials.devise_jwt_secret_key!).first
              current_user = User.find(jwt_payload['sub'])
            rescue JWT::DecodeError, JWT::ExpiredSignature
              # Обработка ошибок происходит в модуле AuthenticationErrors
              raise
            end
          end

          if current_user
            render json: {
              status: {
                code: 200,
                message: 'Logged out successfully.'
              }
            }
          else
            render json: {
              status: {
                code: 401,
                message: 'User not found.'
              }
            }, status: :unauthorized
          end
        end
      end
    end
  end
end
