class ApplicationController < ActionController::API
  include AuthenticationErrors

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user_from_token!

  private

  def authenticate_user_from_token!
    auth_header = request.headers['Authorization']

    if auth_header && auth_header.start_with?('Bearer ')
      token = auth_header.split(' ').last
      begin
        jwt_payload = JWT.decode(token, Rails.application.credentials.devise_jwt_secret_key!).first
        @current_user = User.find(jwt_payload['sub'])
        render_unauthorized unless @current_user
      rescue JWT::DecodeError, JWT::ExpiredSignature
        # Обработка ошибок происходит в модуле AuthenticationErrors
        raise
      end
    else
      render_unauthorized
    end
  end

  def current_user
    @current_user
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[name])
  end
end
