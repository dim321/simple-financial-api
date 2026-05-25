module Api
  module V1
    class AccountsController < ApplicationController
      include AccountErrors
      include AmountValidatable
      include CurrencyNormalizable
      include TransferValidatable

      before_action :set_account, except: %i[create index]
      before_action :normalize_account_currency_param, except: %i[create index]
      before_action :validate_transfer_params!, only: :transfer
      before_action :set_recipient_account, only: :transfer

      def index
        accounts = current_user.accounts.order(:id)

        render_status_payload(
          status: { code: 200, message: "Accounts retrieved successfully." },
          data: accounts.map { |account| serialize(AccountSerializer, account) }
        )
      end

      def show
        render_status_payload(
          status: { code: 200, message: "Account retrieved successfully." },
          data: serialize(AccountSerializer, @account)
        )
      end

      def create
        @account = current_user.accounts.build(account_params)

        if @account.save
          render_status_payload(
            status: { code: 201, message: "Account created successfully." },
            data: serialize(AccountSerializer, @account),
            http_status: :created
          )
        else
          render json: {
            status: {
              code: 422,
              message: "Account creation failed.",
              errors: @account.errors.full_messages
            }
          }, status: :unprocessable_content
        end
      end

      def deposit
        amount = parse_amount!(params[:amount])
        @account.deposit(amount, description: params[:description])

        render_status_payload(
          status: { code: 200, message: "Deposit successful." },
          data: serialize(AccountSerializer, @account.reload)
        )
      end

      def withdraw
        amount = parse_amount!(params[:amount])
        @account.withdraw(amount, description: params[:description])

        render_status_payload(
          status: { code: 200, message: "Withdrawal successful." },
          data: serialize(AccountSerializer, @account.reload)
        )
      end

      def transfer
        amount = parse_amount!(params[:amount])
        result = @account.transfer(amount, @recipient_account, description: params[:description])

        render_status_payload(
          status: { code: 200, message: "Transfer successful." },
          data: {
            sender: serialize(AccountSerializer, result[:source_account]),
            recipient: serialize(AccountSerializer, result[:target_account])
          }
        )
      end

      def hold
        @account.hold_account

        render_status_payload(
          status: { code: 200, message: "Account holded successfully." },
          data: serialize(AccountSerializer, @account.reload)
        )
      end

      def unhold
        @account.unhold_account

        render_status_payload(
          status: { code: 200, message: "Account unholded successfully." },
          data: serialize(AccountSerializer, @account.reload)
        )
      end

      def close
        @account.close_account

        render_status_payload(
          status: { code: 200, message: "Account closed successfully." },
          data: serialize(AccountSerializer, @account.reload)
        )
      end

      def balance
        render_status_payload(
          status: { code: 200, message: "Balance." },
          data: serialize(BalanceSerializer, @account)
        )
      end

      private

      def set_account
        @account = AccountResolver.new(current_user).resolve(
          account_id: params[:id] || params[:account_id],
          currency: params[:currency],
          account_number: params[:account_number]
        )
      end

      def account_params
        permitted = params.require(:account).permit(:currency)
        permitted[:currency] = CurrencyCode.normalize!(permitted[:currency]) if permitted[:currency].present?
        permitted
      rescue CurrencyCode::UnsupportedCurrencyError => e
        raise Account::InvalidCurrencyError, e.message
      end

      def normalize_account_currency_param
        normalize_optional_currency!(params[:currency])
      end

      def set_recipient_account
        @recipient_account = AccountResolver.new(current_user).resolve_recipient(
          email: params[:recipient_email],
          currency: params[:currency]
        )
        raise Account::InvalidAccountError, "Target account unknown" if @recipient_account.nil?
      end
    end
  end
end
