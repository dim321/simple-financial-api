class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :account_number, null: false
      t.bigint :balance_cents, default: 0, null: false
      t.string :currency, default: 'USD', null: false
      t.string :status, default: 'active', null: false
      t.timestamps
    end

    add_index :accounts, [:user_id, :currency], unique: true
    add_index :accounts, :account_number, unique: true

    add_check_constraint :accounts,
                         "balance_cents >= 0",
                         name: "accounts_balance_cents_non_negative",
                         validate: false
    add_check_constraint :accounts,
                         "currency IN ('USD', 'EUR')",
                         name: "accounts_currency_supported",
                         validate: false
    add_check_constraint :accounts,
                         "status IN ('active', 'on_hold', 'closed')",
                         name: "accounts_status_supported",
                         validate: false
  end
end
