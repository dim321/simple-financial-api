module Api
  module V1
    module Auth
      class RegistrationsController < Devise::RegistrationsController
        include RackSessionsFix
        respond_to :json
        skip_before_action :authenticate_user_from_token!, only: %i[new create]

        private

        def respond_with(resource, _opts = {})
          if resource.persisted?
            render json: {
              status: { code: 200, message: 'Signed up successfully.' },
              data: UserSerializer.new(resource).serializable_hash[:data][:attributes]
            }
          else
            render json: {
              status: { message: "User couldn't be created successfully. #{resource.errors.full_messages.to_sentence}" }
            }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end 