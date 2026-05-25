class AddFinancialCheckConstraints < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE transactions SET status = 1 WHERE status IS NULL"
    execute "UPDATE transactions SET transaction_type = 2 WHERE transaction_type IS NULL"

    change_column_null :transactions, :status, false
    change_column_null :transactions, :transaction_type, false

    add_check_constraint :accounts,
                         "balance_cents >= 0",
                         name: "accounts_balance_cents_non_negative",
                         validate: false
    add_check_constraint :accounts,
                         "currency IN ('USD', 'EUR')",
                         name: "accounts_currency_supported",
                         validate: false
    add_check_constraint :accounts,
                         "status IN ('active', 'holded', 'closed')",
                         name: "accounts_status_supported",
                         validate: false

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

  def down
    remove_check_constraint :transactions, name: "transactions_account_shape_matches_type"
    remove_check_constraint :transactions, name: "transactions_type_supported"
    remove_check_constraint :transactions, name: "transactions_status_supported"
    remove_check_constraint :transactions, name: "transactions_currency_supported"
    remove_check_constraint :transactions, name: "transactions_amount_cents_positive"

    remove_check_constraint :accounts, name: "accounts_status_supported"
    remove_check_constraint :accounts, name: "accounts_currency_supported"
    remove_check_constraint :accounts, name: "accounts_balance_cents_non_negative"

    change_column_null :transactions, :transaction_type, true
    change_column_null :transactions, :status, true
  end
end
