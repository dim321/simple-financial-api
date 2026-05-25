module Api
  module V1
    class AccountsController < ApplicationController
      include AccountErrors

      before_action :set_account, except: :create
      before_action :set_recipient_account, only: :transfer

      def show
        render json: {
          status: {
            code: 200,
            message: 'Account retrieved successfully.'
          },
          data: AccountSerializer.new(@account).serializable_hash[:data][:attributes]
        }
      end

      def create
        @account = current_user.accounts.build(account_params)

        if @account.save
          render json: {
            status: {
              code: 201,
              message: 'Account created successfully.'
            },
            data: AccountSerializer.new(@account).serializable_hash[:data][:attributes]
          }, status: :created
        else
          render json: {
            status: {
              code: 422,
              message: 'Account creation failed.',
              errors: @account.errors.full_messages
            }
          }, status: :unprocessable_content
        end
      end

      def deposit
        amount = params[:amount].to_d
        description = params[:description]
        @account.deposit(amount, description: description)

        render json: {
          status: {
            code: 200,
            message: 'Deposit successful.'
          },
          data: AccountSerializer.new(@account).serializable_hash[:data][:attributes]
        }
      end

      def withdraw
        amount = params[:amount].to_d
        description = params[:description]
        @account.withdraw(amount, description: description)

        render json: {
          status: {
            code: 200,
            message: 'Withdrawal successful.'
          },
          data: AccountSerializer.new(@account).serializable_hash[:data][:attributes]
        }
      end

      def transfer
        amount = params[:amount].to_d
        description = params[:description]

        @account.transfer(amount, @recipient_account, description: description)

        render json: {
          status: {
            code: 200,
            message: 'Transfer successful.'
          },
          data: {
            sender: AccountSerializer.new(@account).serializable_hash[:data][:attributes],
            recipient: AccountSerializer.new(@recipient_account).serializable_hash[:data][:attributes]
          }
        }
      end

      def hold
        @account.hold_account
        render json: {
          status: {
            code: 200,
            message: 'Account holded successfully.'
          },
          data: AccountSerializer.new(@account).serializable_hash[:data][:attributes]
        }
      end

      def unhold
        @account.unhold_account
        render json: {
          status: {
            code: 200,
            message: 'Account unholded successfully.'
          },
          data: AccountSerializer.new(@account).serializable_hash[:data][:attributes]
        }
      end

      def close
        @account.close_account
        render json: {
          status: {
            code: 200,
            message: 'Account closed successfully.'
          },
          data: AccountSerializer.new(@account).serializable_hash[:data][:attributes]
        }
      end

      def balance
        # TODO: select user's account by currency or account_number
        @account = current_user.default_account
        render json: {
          status: {
            code: 200,
            message: 'Balance.'
          },
          data: BalanceSerializer.new(@account).serializable_hash[:data][:attributes]
        }
      end

      private

      def set_account
        @account = if params[:id]
          current_user.accounts.find(params[:id])
        else
          current_user.default_account
        end
      end

      def account_params
        params.require(:account).permit(:currency)
      end

      def set_recipient_account
        @recipient_account = User.find_by(email: params[:recipient_email])&.default_account
      end
    end
  end
end
