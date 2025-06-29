module Api
  module V1
    class AccountsController < ApplicationController
      include AccountErrors

      before_action :set_account, except: :create

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
          }, status: :unprocessable_entity
        end
      end

      def deposit
        amount = transfer_params[:amount]
        @account.deposit(amount)

        render json: {
          status: {
            code: 200,
            message: 'Deposit successful.'
          },
          data: AccountSerializer.new(@account).serializable_hash[:data][:attributes]
        }
      end

      def withdraw
        amount = transfer_params[:amount].to_d
        @account.withdraw(amount)

        render json: {
          status: {
            code: 200,
            message: 'Withdrawal successful.'
          },
          data: AccountSerializer.new(@account).serializable_hash[:data][:attributes]
        }
      end

      def transfer
        amount = transfer_params[:amount].to_d
        target_account_number = transfer_params[:target_account_number]
        recipient_email = transfer_params[:recipient_email]

        recipient_account = Account.find_by(account_number: target_account_number) if target_account_number.present?
        recipient_account = User.find_by(email: recipient_email).default_account if recipient_email.present?

        @account.transfer(amount, recipient_account)

        render json: {
          status: {
            code: 200,
            message: 'Transfer successful.'
          },
          data: {
            sender: AccountSerializer.new(@account).serializable_hash[:data][:attributes],
            recipient: AccountSerializer.new(recipient_account).serializable_hash[:data][:attributes]
          }
        }
      end

      def hold
        @account.freeze_account
        render json: {
          status: {
            code: 200,
            message: 'Account frozen successfully.'
          },
          data: AccountSerializer.new(@account).serializable_hash[:data][:attributes]
        }
      end

      def unhold
        @account.unfreeze_account
        render json: {
          status: {
            code: 200,
            message: 'Account unfrozen successfully.'
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
        # TODO: select user'saccount by currency or account_number
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
        params.require(:account).permit(:currency, :account_number)
      end

      def transfer_params
        params.require(:transfer).permit(:amount, :currency, :recipient_email, :target_account_number)
      end
    end
  end
end
