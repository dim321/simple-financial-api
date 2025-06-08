module AuthenticationErrors
  extend ActiveSupport::Concern

  included do
    rescue_from JWT::DecodeError, with: :handle_jwt_decode_error
    rescue_from JWT::ExpiredSignature, with: :handle_jwt_expired_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
  end

  private

  def handle_jwt_decode_error
    render json: {
      status: {
        code: 401,
        message: 'Invalid authentication token'
      }
    }, status: :unauthorized
  end

  def handle_jwt_expired_error
    render json: {
      status: {
        code: 401,
        message: 'Authentication token has expired'
      }
    }, status: :unauthorized
  end

  def handle_record_not_found
    render json: {
      status: {
        code: 404,
        message: 'Resource not found'
      }
    }, status: :not_found
  end

  def render_unauthorized
    render json: {
      status: {
        code: 401,
        message: 'Unauthorized. Please authenticate to access this resource.'
      }
    }, status: :unauthorized
  end
end
