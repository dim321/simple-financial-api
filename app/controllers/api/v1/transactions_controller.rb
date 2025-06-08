module Api
  module V1
    class TransactionsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_account
      before_action :set_transaction, only: [:show, :reverse]

      def index
        @transactions = @account.transactions.page(params[:page]).per(params[:per_page])

        render json: {
          status: {
            code: 200,
            message: 'Transactions retrieved successfully.'
          },
          data: TransactionSerializer.new(@transactions).serializable_hash[:data],
          meta: {
            current_page: @transactions.current_page,
            total_pages: @transactions.total_pages,
            total_count: @transactions.total_count
          }
        }
      end

      def show
        render json: {
          status: {
            code: 200,
            message: 'Transaction retrieved successfully.'
          },
          data: TransactionSerializer.new(@transaction).serializable_hash[:data][:attributes]
        }
      end

      def reverse
        @transaction.reverse!

        render json: {
          status: {
            code: 200,
            message: 'Transaction reversed successfully.'
          },
          data: TransactionSerializer.new(@transaction).serializable_hash[:data][:attributes]
        }
      rescue StandardError => e
        render json: {
          status: {
            code: 422,
            message: e.message
          }
        }, status: :unprocessable_entity
      end

      private

      def set_account
        @account = current_user.accounts.find(params[:account_id])
      rescue ActiveRecord::RecordNotFound
        render json: {
          status: {
            code: 404,
            message: 'Account not found.'
          }
        }, status: :not_found
      end

      def set_transaction
        @transaction = @account.transactions.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: {
          status: {
            code: 404,
            message: 'Transaction not found.'
          }
        }, status: :not_found
      end
    end
  end
end
