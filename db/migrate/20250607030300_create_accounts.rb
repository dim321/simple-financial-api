class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :account_number, null: false
      t.decimal :balance, precision: 10, scale: 2, default: 0.0, null: false
      t.string :currency, default: 'USD', null: false
      t.string :status, default: 'active', null: false
      t.timestamps
    end

    add_index :accounts, [:user_id, :currency], unique: true
    add_index :accounts, :account_number, unique: true
  end
end
