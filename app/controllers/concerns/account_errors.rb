module AccountErrors
  extend ActiveSupport::Concern

  included do
    rescue_from Account::InactiveAccountError do |e|
      render json: {
        status: {
          code: 422,
          message: e.message
        }
      }, status: :unprocessable_content
    end

    rescue_from Account::TargetAccountInactiveError do |e|
      render json: {
        status: {
          code: 422,
          message: e.message
        }
      }, status: :unprocessable_content
    end

    rescue_from Account::InvalidAmountError do |e|
      render json: {
        status: {
          code: 422,
          message: e.message
        }
      }, status: :unprocessable_content
    end

    rescue_from Account::InsufficientFundsError do |e|
      render json: {
        status: {
          code: 422,
          message: e.message
        }
      }, status: :unprocessable_content
    end

    rescue_from Account::SelfTransferError do |e|
      render json: {
        status: {
          code: 422,
          message: e.message
        }
      }, status: :unprocessable_content
    end

    rescue_from Account::DifferentCurrencyError do |e|
      render json: {
        status: {
          code: 422,
          message: e.message
        }
      }, status: :unprocessable_content
    end

    rescue_from Account::NonZeroBalanceError do |e|
      render json: {
        status: {
          code: 422,
          message: e.message
        }
      }, status: :unprocessable_content
    end

    rescue_from Account::InvalidAccountError do |e|
      render json: {
        status: {
          code: 422,
          message: e.message
        }
      }, status: :unprocessable_content
    end

    rescue_from ArgumentError do |e|
      render json: {
        status: {
          code: 422,
          message: 'Invalid amount.'
        }
      }, status: :unprocessable_content
    end

    rescue_from ActiveRecord::RecordNotFound do |e|
      render json: {
        status: {
          code: 404,
          message: 'Account not found.'
        }
      }, status: :not_found
    end
  end
end
