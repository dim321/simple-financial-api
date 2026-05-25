module Api
  module V1
    class TransactionsController < ApplicationController
      include AccountErrors

      before_action :set_account
      before_action :set_transaction, only: %i[show reverse]

      def index
        entries = @account.ledger_entries

        render_status_payload(
          status: { code: 200, message: "Transactions retrieved successfully." },
          data: entries.map { |entry| serialize(TransactionSerializer, entry) }
        )
      end

      def show
        render_status_payload(
          status: { code: 200, message: "Transaction retrieved successfully." },
          data: serialize(TransactionSerializer, @transaction)
        )
      end

      def reverse
        AccountOperations::ReverseService.new(@transaction).call

        render_status_payload(
          status: { code: 200, message: "Transaction reversed successfully." },
          data: serialize(TransactionSerializer, @transaction.reload)
        )
      end

      private

      def set_account
        @account = AccountResolver.new(current_user).resolve(
          account_id: params[:account_id],
          currency: params[:currency],
          account_number: params[:account_number]
        )
      end

      def set_transaction
        @transaction = @account.ledger_entries.find(params[:id])
      end
    end
  end
end
