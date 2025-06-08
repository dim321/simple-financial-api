# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_06_07_030313) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "account_number", null: false
    t.decimal "balance", precision: 10, scale: 2, default: "0.0", null: false
    t.string "currency", default: "USD", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_number"], name: "index_accounts_on_account_number", unique: true
    t.index ["user_id", "currency"], name: "index_accounts_on_user_id_and_currency", unique: true
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "source_account_id"
    t.bigint "target_account_id"
    t.decimal "amount", precision: 19, scale: 4, null: false
    t.string "currency", null: false
    t.string "transaction_type", null: false
    t.string "status", default: "completed", null: false
    t.text "description"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_transactions_on_created_at"
    t.index ["source_account_id"], name: "index_transactions_on_source_account_id"
    t.index ["status"], name: "index_transactions_on_status"
    t.index ["target_account_id"], name: "index_transactions_on_target_account_id"
    t.index ["transaction_type"], name: "index_transactions_on_transaction_type"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "jti", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "transactions", "accounts", column: "source_account_id"
  add_foreign_key "transactions", "accounts", column: "target_account_id"
end
