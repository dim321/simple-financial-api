module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        include RackSessionsFix
        include AuthenticationErrors
        respond_to :json
        skip_before_action :authenticate_user!, only: %i[create]

        private

        def respond_with(resource, _opts = {})
          if resource.persisted?
            render json: {
              status: {
                code: 200,
                message: "Logged in successfully."
              },
              data: UserSerializer.new(resource).serializable_hash[:data][:attributes]
            }
          else
            render json: {
              status: {
                code: 401,
                message: "Invalid email or password."
              }
            }, status: :unauthorized
          end
        end

        def respond_to_on_destroy(_options = {})
          if current_user
            sign_out(current_user)
            render json: {
              status: {
                code: 200,
                message: "Logged out successfully."
              }
            }
          else
            render_unauthorized
          end
        end
      end
    end
  end
end
