class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :source_account, null: true, foreign_key: { to_table: :accounts }
      t.references :target_account, null: true, foreign_key: { to_table: :accounts }
      t.decimal :amount, precision: 19, scale: 4, null: false
      t.string :currency, null: false
      t.string :transaction_type, null: false
      t.string :status, null: false, default: 'completed'
      t.text :description
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :transactions, :transaction_type
    add_index :transactions, :status
    add_index :transactions, :created_at
  end
end
