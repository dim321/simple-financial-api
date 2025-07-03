class AddStatusToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :status, :integer
    add_column :transactions, :transaction_type, :integer
  end
end
