class AddOriginalTransactionToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_reference :transactions,
                  :original_transaction,
                  foreign_key: { to_table: :transactions },
                  index: false

    add_index :transactions,
              :original_transaction_id,
              unique: true,
              where: "original_transaction_id IS NOT NULL",
              name: "index_transactions_on_unique_original_transaction"
  end
end
