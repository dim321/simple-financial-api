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

ActiveRecord::Schema[8.1].define(version: 2026_05_25_134000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "account_number", null: false
    t.bigint "balance_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_number"], name: "index_accounts_on_account_number", unique: true
    t.index ["user_id", "currency"], name: "index_accounts_on_user_id_and_currency", unique: true
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  add_check_constraint "accounts", "balance_cents >= 0", name: "accounts_balance_cents_non_negative", validate: false
  add_check_constraint "accounts", "currency::text = ANY (ARRAY['USD'::character varying, 'EUR'::character varying]::text[])", name: "accounts_currency_supported", validate: false
  add_check_constraint "accounts", "status::text = ANY (ARRAY['active'::character varying, 'on_hold'::character varying, 'closed'::character varying]::text[])", name: "accounts_status_supported", validate: false

  create_table "idempotency_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "request_fingerprint", null: false
    t.string "request_method", null: false
    t.string "request_path", null: false
    t.jsonb "response_body"
    t.integer "response_status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_idempotency_keys_on_created_at"
    t.index ["user_id", "key"], name: "index_idempotency_keys_on_user_id_and_key", unique: true
    t.index ["user_id"], name: "index_idempotency_keys_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.text "description"
    t.jsonb "metadata", default: {}
    t.bigint "original_transaction_id"
    t.bigint "source_account_id"
    t.integer "status", null: false
    t.bigint "target_account_id"
    t.integer "transaction_type", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_transactions_on_created_at"
    t.index ["original_transaction_id"], name: "index_transactions_on_unique_original_transaction", unique: true, where: "(original_transaction_id IS NOT NULL)"
    t.index ["source_account_id"], name: "index_transactions_on_source_account_id"
    t.index ["target_account_id"], name: "index_transactions_on_target_account_id"
  end

  add_check_constraint "transactions", "amount_cents > 0", name: "transactions_amount_cents_positive", validate: false
  add_check_constraint "transactions", "currency::text = ANY (ARRAY['USD'::character varying, 'EUR'::character varying]::text[])", name: "transactions_currency_supported", validate: false
  add_check_constraint "transactions", "status = ANY (ARRAY[0, 1, 2, 3])", name: "transactions_status_supported", validate: false
  add_check_constraint "transactions", "transaction_type = 0 AND source_account_id IS NULL AND target_account_id IS NOT NULL OR transaction_type = 1 AND source_account_id IS NOT NULL AND target_account_id IS NULL OR transaction_type = 2 AND source_account_id IS NOT NULL AND target_account_id IS NOT NULL", name: "transactions_account_shape_matches_type", validate: false
  add_check_constraint "transactions", "transaction_type = ANY (ARRAY[0, 1, 2])", name: "transactions_type_supported", validate: false

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "jti", null: false
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "idempotency_keys", "users"
  add_foreign_key "transactions", "accounts", column: "source_account_id"
  add_foreign_key "transactions", "accounts", column: "target_account_id"
  add_foreign_key "transactions", "transactions", column: "original_transaction_id"
end
