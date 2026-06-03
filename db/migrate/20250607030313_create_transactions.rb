class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :source_account, null: true, foreign_key: { to_table: :accounts }
      t.references :target_account, null: true, foreign_key: { to_table: :accounts }
      t.bigint :amount_cents, null: false
      t.string :currency, null: false
      t.integer :transaction_type, null: false
      t.integer :status, null: false
      t.text :description
      t.jsonb :metadata, default: {}
      t.references :original_transaction, null: true, foreign_key: { to_table: :transactions }, index: false

      t.timestamps
    end

    add_index :transactions, :created_at
    add_index :transactions,
              :original_transaction_id,
              unique: true,
              where: "original_transaction_id IS NOT NULL",
              name: "index_transactions_on_unique_original_transaction"

    add_check_constraint :transactions,
                         "amount_cents > 0",
                         name: "transactions_amount_cents_positive",
                         validate: false
    add_check_constraint :transactions,
                         "currency IN ('USD', 'EUR')",
                         name: "transactions_currency_supported",
                         validate: false
    add_check_constraint :transactions,
                         "status IN (0, 1, 2, 3)",
                         name: "transactions_status_supported",
                         validate: false
    add_check_constraint :transactions,
                         "transaction_type IN (0, 1, 2)",
                         name: "transactions_type_supported",
                         validate: false
    add_check_constraint :transactions,
                         <<~SQL.squish,
                           (
                             transaction_type = 0
                             AND source_account_id IS NULL
                             AND target_account_id IS NOT NULL
                           )
                           OR (
                             transaction_type = 1
                             AND source_account_id IS NOT NULL
                             AND target_account_id IS NULL
                           )
                           OR (
                             transaction_type = 2
                             AND source_account_id IS NOT NULL
                             AND target_account_id IS NOT NULL
                           )
                         SQL
                         name: "transactions_account_shape_matches_type",
                         validate: false
  end
end
