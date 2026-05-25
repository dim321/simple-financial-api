module AccountErrors
  extend ActiveSupport::Concern

  OPERATION_ERRORS = [
    Account::InactiveAccountError,
    Account::InvalidAmountError,
    Account::InsufficientFundsError,
    Account::SelfTransferError,
    Account::DifferentCurrencyError,
    Account::NonZeroBalanceError,
    Account::InvalidAccountError,
    AccountOperations::ReverseService::NotReversibleError
  ].freeze

  included do
    OPERATION_ERRORS.each do |error_class|
      rescue_from error_class, with: :render_operation_error
    end

    rescue_from ActiveRecord::RecordNotFound, with: :render_account_not_found
  end

  private

  def render_operation_error(exception)
    render json: {
      status: {
        code: 422,
        message: exception.message
      }
    }, status: :unprocessable_content
  end

  def render_account_not_found(_exception)
    render json: {
      status: {
        code: 404,
        message: "Account not found."
      }
    }, status: :not_found
  end
end
