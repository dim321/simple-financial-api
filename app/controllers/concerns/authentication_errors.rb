module AuthenticationErrors
  extend ActiveSupport::Concern

  included do
    rescue_from JWT::DecodeError, with: :handle_jwt_decode_error
    rescue_from JWT::ExpiredSignature, with: :handle_jwt_expired_error
  end

  private

  def handle_jwt_decode_error
    render_unauthorized("Invalid authentication token")
  end

  def handle_jwt_expired_error
    render_unauthorized("Authentication token has expired")
  end

  def render_unauthorized(message = "Unauthorized. Please authenticate to access this resource.")
    render json: {
      status: {
        code: 401,
        message: message
      }
    }, status: :unauthorized
  end
end
