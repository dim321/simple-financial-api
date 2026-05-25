class StoreMoneyAmountsAsCents < ActiveRecord::Migration[8.0]
  def up
    add_column :accounts, :balance_cents, :bigint, null: false, default: 0
    add_column :transactions, :amount_cents, :bigint, null: false, default: 0

    execute "UPDATE accounts SET balance_cents = ROUND(balance * 100)"
    execute "UPDATE transactions SET amount_cents = ROUND(amount * 100)"

    change_column_default :transactions, :amount_cents, from: 0, to: nil

    remove_column :accounts, :balance
    remove_column :transactions, :amount
  end

  def down
    add_column :accounts, :balance, :decimal, precision: 10, scale: 2, default: "0.0", null: false
    add_column :transactions, :amount, :decimal, precision: 19, scale: 4, null: false, default: "0.0"

    execute "UPDATE accounts SET balance = balance_cents / 100.0"
    execute "UPDATE transactions SET amount = amount_cents / 100.0"

    change_column_default :transactions, :amount, from: "0.0", to: nil

    remove_column :accounts, :balance_cents
    remove_column :transactions, :amount_cents
  end
end
