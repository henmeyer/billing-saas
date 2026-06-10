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

ActiveRecord::Schema[7.1].define(version: 2026_06_10_130002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "account_users", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "user_id"], name: "index_account_users_on_account_id_and_user_id", unique: true
    t.index ["account_id"], name: "index_account_users_on_account_id"
    t.index ["user_id"], name: "index_account_users_on_user_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
  end

  create_table "api_keys", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "token_digest", null: false
    t.string "last_four", null: false
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_api_keys_on_account_id"
    t.index ["token_digest"], name: "index_api_keys_on_token_digest", unique: true
  end

  create_table "charges", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "subscription_id", null: false
    t.string "gateway", null: false
    t.string "gateway_charge_id"
    t.integer "amount_cents", null: false
    t.string "status", default: "pending", null: false
    t.date "due_date"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "currency_id"
    t.string "redirect_url"
    t.jsonb "charge_data", default: {}, null: false
    t.index ["currency_id"], name: "index_charges_on_currency_id"
    t.index ["customer_id"], name: "index_charges_on_customer_id"
    t.index ["gateway", "gateway_charge_id"], name: "index_charges_on_gateway_and_gateway_charge_id", unique: true, where: "(gateway_charge_id IS NOT NULL)"
    t.index ["subscription_id"], name: "index_charges_on_subscription_id"
  end

  create_table "credit_alerts", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "credit_type_id", null: false
    t.integer "threshold", null: false
    t.datetime "period_start", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_type_id"], name: "index_credit_alerts_on_credit_type_id"
    t.index ["customer_id"], name: "index_credit_alerts_on_customer_id"
  end

  create_table "credit_snapshots", force: :cascade do |t|
    t.bigint "subscription_period_id", null: false
    t.bigint "credit_type_id", null: false
    t.integer "used", default: 0, null: false
    t.integer "limit", default: 0, null: false
    t.integer "balance", default: 0, null: false
    t.float "usage_percent", default: 0.0, null: false
    t.datetime "synced_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_type_id"], name: "index_credit_snapshots_on_credit_type_id"
    t.index ["subscription_period_id", "credit_type_id"], name: "index_credit_snapshots_on_period_and_type", unique: true
    t.index ["subscription_period_id"], name: "index_credit_snapshots_on_subscription_period_id"
  end

  create_table "credit_types", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.string "unit", null: false
    t.string "reset_cycle", default: "billing_cycle", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "key"], name: "index_credit_types_on_account_id_and_key", unique: true
    t.index ["account_id"], name: "index_credit_types_on_account_id"
  end

  create_table "currencies", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.string "symbol", null: false
    t.boolean "default", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "code"], name: "index_currencies_on_account_id_and_code", unique: true
    t.index ["account_id"], name: "index_currencies_on_account_id"
  end

  create_table "customer_identities", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "integration_id", null: false
    t.string "external_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "integration_id"], name: "idx_customer_identities_customer_integration", unique: true
    t.index ["customer_id"], name: "index_customer_identities_on_customer_id"
    t.index ["integration_id", "external_id"], name: "idx_customer_identities_integration_external", unique: true
    t.index ["integration_id"], name: "index_customer_identities_on_integration_id"
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "document"
    t.string "phone"
    t.string "status", default: "active", null: false
    t.integer "health_score", default: 100, null: false
    t.jsonb "gateway_data", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "currency_id"
    t.index ["account_id", "email"], name: "index_customers_on_account_id_and_email", unique: true
    t.index ["account_id"], name: "index_customers_on_account_id"
    t.index ["currency_id"], name: "index_customers_on_currency_id"
  end

  create_table "feature_types", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "key"], name: "index_feature_types_on_account_id_and_key", unique: true
    t.index ["account_id"], name: "index_feature_types_on_account_id"
  end

  create_table "import_jobs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.string "gateway", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "preview", default: {}, null: false
    t.jsonb "decisions", default: {}, null: false
    t.jsonb "result", default: {}, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "integration_id"
    t.jsonb "identities", default: {}, null: false
    t.index ["account_id"], name: "index_import_jobs_on_account_id"
    t.index ["integration_id"], name: "index_import_jobs_on_integration_id"
    t.index ["user_id"], name: "index_import_jobs_on_user_id"
  end

  create_table "integration_api_keys", force: :cascade do |t|
    t.bigint "integration_id", null: false
    t.string "name", null: false
    t.string "token_digest", null: false
    t.string "last_four", null: false
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["integration_id"], name: "index_integration_api_keys_on_integration_id"
    t.index ["token_digest"], name: "index_integration_api_keys_on_token_digest", unique: true
  end

  create_table "integration_field_configs", force: :cascade do |t|
    t.bigint "integration_id", null: false
    t.bigint "license_type_id"
    t.bigint "credit_type_id"
    t.string "field_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "feature_type_id"
    t.index ["credit_type_id"], name: "index_integration_field_configs_on_credit_type_id"
    t.index ["feature_type_id"], name: "index_integration_field_configs_on_feature_type_id"
    t.index ["integration_id", "credit_type_id"], name: "idx_integration_field_credit", unique: true, where: "(credit_type_id IS NOT NULL)"
    t.index ["integration_id", "license_type_id"], name: "idx_integration_field_license", unique: true, where: "(license_type_id IS NOT NULL)"
    t.index ["integration_id"], name: "index_integration_field_configs_on_integration_id"
    t.index ["license_type_id"], name: "index_integration_field_configs_on_license_type_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "url", null: false
    t.string "secret", null: false
    t.string "events", default: [], array: true
    t.boolean "active", default: true, null: false
    t.integer "retry_count", default: 5, null: false
    t.datetime "last_error_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_integrations_on_account_id"
  end

  create_table "license_types", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.string "unit", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "key"], name: "index_license_types_on_account_id_and_key", unique: true
    t.index ["account_id"], name: "index_license_types_on_account_id"
  end

  create_table "payment_gateways", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "provider", null: false
    t.string "api_key_enc", null: false
    t.string "webhook_secret"
    t.boolean "active", default: true, null: false
    t.boolean "default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "gateway_data", default: {}, null: false
    t.index ["account_id", "provider"], name: "index_payment_gateways_on_account_id_and_provider", unique: true
    t.index ["account_id"], name: "index_payment_gateways_on_account_id"
  end

  create_table "plan_credits", force: :cascade do |t|
    t.bigint "plan_id", null: false
    t.bigint "credit_type_id", null: false
    t.integer "quantity", default: 0, null: false
    t.boolean "rollover", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "extra_unit_size", default: 0
    t.integer "extra_unit_price_cents", default: 0
    t.boolean "allow_extras", default: false
    t.index ["credit_type_id"], name: "index_plan_credits_on_credit_type_id"
    t.index ["plan_id", "credit_type_id"], name: "index_plan_credits_on_plan_id_and_credit_type_id", unique: true
    t.index ["plan_id"], name: "index_plan_credits_on_plan_id"
  end

  create_table "plan_features", force: :cascade do |t|
    t.bigint "plan_id", null: false
    t.bigint "feature_type_id", null: false
    t.boolean "enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_type_id"], name: "index_plan_features_on_feature_type_id"
    t.index ["plan_id", "feature_type_id"], name: "index_plan_features_on_plan_id_and_feature_type_id", unique: true
    t.index ["plan_id"], name: "index_plan_features_on_plan_id"
  end

  create_table "plan_integrations", force: :cascade do |t|
    t.bigint "plan_id", null: false
    t.bigint "integration_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["integration_id"], name: "index_plan_integrations_on_integration_id"
    t.index ["plan_id", "integration_id"], name: "index_plan_integrations_on_plan_id_and_integration_id", unique: true
    t.index ["plan_id"], name: "index_plan_integrations_on_plan_id"
  end

  create_table "plan_licenses", force: :cascade do |t|
    t.bigint "plan_id", null: false
    t.bigint "license_type_id", null: false
    t.integer "quantity", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["license_type_id"], name: "index_plan_licenses_on_license_type_id"
    t.index ["plan_id", "license_type_id"], name: "index_plan_licenses_on_plan_id_and_license_type_id", unique: true
    t.index ["plan_id"], name: "index_plan_licenses_on_plan_id"
  end

  create_table "plan_prices", force: :cascade do |t|
    t.bigint "plan_id", null: false
    t.bigint "currency_id", null: false
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_id"], name: "index_plan_prices_on_currency_id"
    t.index ["plan_id", "currency_id"], name: "index_plan_prices_on_plan_id_and_currency_id", unique: true
    t.index ["plan_id"], name: "index_plan_prices_on_plan_id"
  end

  create_table "plan_pricing_tiers", force: :cascade do |t|
    t.bigint "plan_id", null: false
    t.bigint "currency_id", null: false
    t.integer "from_unit", null: false
    t.integer "to_unit"
    t.integer "unit_amount_cents", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_id"], name: "index_plan_pricing_tiers_on_currency_id"
    t.index ["plan_id", "currency_id", "from_unit"], name: "idx_plan_pricing_tiers_unique", unique: true
    t.index ["plan_id"], name: "index_plan_pricing_tiers_on_plan_id"
  end

  create_table "plans", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "billing_cycle", default: "monthly", null: false
    t.integer "trial_days", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "archived_at"
    t.jsonb "gateway_data", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pricing_model", default: "flat", null: false
    t.bigint "pricing_license_type_id"
    t.bigint "pricing_credit_type_id"
    t.index ["account_id"], name: "index_plans_on_account_id"
    t.index ["pricing_credit_type_id"], name: "index_plans_on_pricing_credit_type_id"
    t.index ["pricing_license_type_id"], name: "index_plans_on_pricing_license_type_id"
  end

  create_table "product_prices", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "currency_id", null: false
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_id"], name: "index_product_prices_on_currency_id"
    t.index ["product_id", "currency_id"], name: "index_product_prices_on_product_id_and_currency_id", unique: true
    t.index ["product_id"], name: "index_product_prices_on_product_id"
  end

  create_table "product_pricing_tiers", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "currency_id", null: false
    t.integer "from_unit", null: false
    t.integer "to_unit"
    t.integer "unit_amount_cents", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_id"], name: "index_product_pricing_tiers_on_currency_id"
    t.index ["product_id", "currency_id", "from_unit"], name: "idx_product_pricing_tiers_unique", unique: true
    t.index ["product_id"], name: "index_product_pricing_tiers_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "product_type", default: "one_time", null: false
    t.bigint "credit_type_id"
    t.integer "credit_quantity", default: 0
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pricing_model", default: "flat", null: false
    t.bigint "pricing_license_type_id"
    t.bigint "pricing_credit_type_id"
    t.index ["account_id"], name: "index_products_on_account_id"
    t.index ["credit_type_id"], name: "index_products_on_credit_type_id"
    t.index ["pricing_credit_type_id"], name: "index_products_on_pricing_credit_type_id"
    t.index ["pricing_license_type_id"], name: "index_products_on_pricing_license_type_id"
  end

  create_table "subscription_period_credits", force: :cascade do |t|
    t.bigint "subscription_period_id", null: false
    t.bigint "credit_type_id", null: false
    t.integer "quantity", null: false
    t.integer "base", null: false
    t.integer "extras", default: 0, null: false
    t.integer "extra_packages", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_type_id"], name: "index_subscription_period_credits_on_credit_type_id"
    t.index ["subscription_period_id", "credit_type_id"], name: "idx_sub_period_credits_unique", unique: true
    t.index ["subscription_period_id"], name: "index_subscription_period_credits_on_subscription_period_id"
  end

  create_table "subscription_period_licenses", force: :cascade do |t|
    t.bigint "subscription_period_id", null: false
    t.bigint "license_type_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["license_type_id"], name: "index_subscription_period_licenses_on_license_type_id"
    t.index ["subscription_period_id", "license_type_id"], name: "idx_sub_period_licenses_unique", unique: true
    t.index ["subscription_period_id"], name: "index_subscription_period_licenses_on_subscription_period_id"
  end

  create_table "subscription_periods", force: :cascade do |t|
    t.bigint "subscription_id", null: false
    t.datetime "period_start", null: false
    t.datetime "period_end", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "amount_cents", default: 0, null: false
    t.integer "base_amount_cents", default: 0, null: false
    t.integer "extras_amount_cents", default: 0, null: false
    t.index ["subscription_id", "period_start"], name: "index_subscription_periods_on_subscription_id_and_period_start", unique: true
    t.index ["subscription_id"], name: "index_subscription_periods_on_subscription_id"
  end

  create_table "subscription_plan_changes", force: :cascade do |t|
    t.bigint "subscription_id", null: false
    t.bigint "from_plan_id", null: false
    t.bigint "to_plan_id", null: false
    t.string "reason"
    t.integer "changed_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_plan_id"], name: "index_subscription_plan_changes_on_from_plan_id"
    t.index ["subscription_id"], name: "index_subscription_plan_changes_on_subscription_id"
    t.index ["to_plan_id"], name: "index_subscription_plan_changes_on_to_plan_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "plan_id", null: false
    t.string "status", default: "active", null: false
    t.string "gateway", null: false
    t.string "gateway_subscription_id"
    t.datetime "started_at", null: false
    t.datetime "trial_ends_at"
    t.datetime "cancelled_at"
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "currency_id"
    t.jsonb "metadata", default: {}, null: false
    t.integer "base_price_cents", default: 0, null: false
    t.string "currency_code", default: "BRL", null: false
    t.bigint "integration_id", null: false
    t.index ["currency_id"], name: "index_subscriptions_on_currency_id"
    t.index ["customer_id", "integration_id"], name: "idx_unique_active_subscription_per_customer_integration", unique: true, where: "((status)::text = ANY ((ARRAY['active'::character varying, 'trialing'::character varying, 'past_due'::character varying])::text[]))"
    t.index ["customer_id"], name: "index_subscriptions_on_customer_id"
    t.index ["gateway", "gateway_subscription_id"], name: "index_subscriptions_on_gateway_and_gateway_subscription_id", unique: true, where: "(gateway_subscription_id IS NOT NULL)"
    t.index ["integration_id"], name: "index_subscriptions_on_integration_id"
    t.index ["plan_id"], name: "index_subscriptions_on_plan_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.bigint "account_id"
    t.string "name", default: "", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["type"], name: "index_users_on_type"
  end

  create_table "webhook_logs", force: :cascade do |t|
    t.bigint "integration_id", null: false
    t.bigint "customer_id", null: false
    t.string "event", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "next_retry_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_test", default: false, null: false
    t.integer "response_code"
    t.text "response_body"
    t.integer "duration_ms"
    t.string "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["customer_id"], name: "index_webhook_logs_on_customer_id"
    t.index ["integration_id", "status"], name: "index_webhook_logs_on_integration_id_and_status"
    t.index ["integration_id"], name: "index_webhook_logs_on_integration_id"
    t.index ["next_retry_at"], name: "index_webhook_logs_on_next_retry_at"
    t.index ["uuid"], name: "index_webhook_logs_on_uuid", unique: true
  end

  add_foreign_key "account_users", "accounts"
  add_foreign_key "account_users", "users"
  add_foreign_key "api_keys", "accounts"
  add_foreign_key "charges", "currencies"
  add_foreign_key "charges", "customers"
  add_foreign_key "charges", "subscriptions"
  add_foreign_key "credit_alerts", "credit_types"
  add_foreign_key "credit_alerts", "customers"
  add_foreign_key "credit_snapshots", "credit_types"
  add_foreign_key "credit_snapshots", "subscription_periods"
  add_foreign_key "credit_types", "accounts"
  add_foreign_key "currencies", "accounts"
  add_foreign_key "customer_identities", "customers"
  add_foreign_key "customer_identities", "integrations"
  add_foreign_key "customers", "accounts"
  add_foreign_key "customers", "currencies"
  add_foreign_key "feature_types", "accounts"
  add_foreign_key "import_jobs", "accounts"
  add_foreign_key "import_jobs", "integrations"
  add_foreign_key "import_jobs", "users"
  add_foreign_key "integration_api_keys", "integrations"
  add_foreign_key "integration_field_configs", "credit_types"
  add_foreign_key "integration_field_configs", "feature_types"
  add_foreign_key "integration_field_configs", "integrations"
  add_foreign_key "integration_field_configs", "license_types"
  add_foreign_key "integrations", "accounts"
  add_foreign_key "license_types", "accounts"
  add_foreign_key "payment_gateways", "accounts"
  add_foreign_key "plan_credits", "credit_types"
  add_foreign_key "plan_credits", "plans"
  add_foreign_key "plan_features", "feature_types"
  add_foreign_key "plan_features", "plans"
  add_foreign_key "plan_integrations", "integrations"
  add_foreign_key "plan_integrations", "plans"
  add_foreign_key "plan_licenses", "license_types"
  add_foreign_key "plan_licenses", "plans"
  add_foreign_key "plan_prices", "currencies"
  add_foreign_key "plan_prices", "plans"
  add_foreign_key "plan_pricing_tiers", "currencies"
  add_foreign_key "plan_pricing_tiers", "plans"
  add_foreign_key "plans", "accounts"
  add_foreign_key "plans", "credit_types", column: "pricing_credit_type_id"
  add_foreign_key "plans", "license_types", column: "pricing_license_type_id"
  add_foreign_key "product_prices", "currencies"
  add_foreign_key "product_prices", "products"
  add_foreign_key "product_pricing_tiers", "currencies"
  add_foreign_key "product_pricing_tiers", "products"
  add_foreign_key "products", "accounts"
  add_foreign_key "products", "credit_types"
  add_foreign_key "products", "credit_types", column: "pricing_credit_type_id"
  add_foreign_key "products", "license_types", column: "pricing_license_type_id"
  add_foreign_key "subscription_period_credits", "credit_types"
  add_foreign_key "subscription_period_credits", "subscription_periods"
  add_foreign_key "subscription_period_licenses", "license_types"
  add_foreign_key "subscription_period_licenses", "subscription_periods"
  add_foreign_key "subscription_periods", "subscriptions"
  add_foreign_key "subscription_plan_changes", "plans", column: "from_plan_id"
  add_foreign_key "subscription_plan_changes", "plans", column: "to_plan_id"
  add_foreign_key "subscription_plan_changes", "subscriptions"
  add_foreign_key "subscriptions", "currencies"
  add_foreign_key "subscriptions", "customers"
  add_foreign_key "subscriptions", "integrations"
  add_foreign_key "subscriptions", "plans"
  add_foreign_key "users", "accounts"
  add_foreign_key "webhook_logs", "customers"
  add_foreign_key "webhook_logs", "integrations"
end
