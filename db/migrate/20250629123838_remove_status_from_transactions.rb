class RemoveStatusFromTransactions < ActiveRecord::Migration[8.0]
  def change
    remove_column :transactions, :status, :string
    remove_column :transactions, :transaction_type, :string
  end
end
