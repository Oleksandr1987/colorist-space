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

ActiveRecord::Schema[8.1].define(version: 2026_09_22_150000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointment_services_relations", force: :cascade do |t|
    t.integer "appointment_id", null: false
    t.datetime "created_at", null: false
    t.integer "price", null: false
    t.integer "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id", "service_id"], name: "appt_serv_in", unique: true
    t.index ["appointment_id"], name: "index_appointment_services_relations_on_appointment_id"
    t.index ["service_id"], name: "index_appointment_services_relations_on_service_id"
  end

  create_table "appointments", force: :cascade do |t|
    t.date "appointment_date"
    t.time "appointment_time"
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.time "end_time"
    t.text "notes"
    t.string "service_name"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["client_id"], name: "index_appointments_on_client_id"
    t.index ["user_id"], name: "index_appointments_on_user_id"
  end

  create_table "care_products", force: :cascade do |t|
    t.string "brand"
    t.string "category"
    t.datetime "created_at", null: false
    t.string "name"
    t.decimal "purchase_price", precision: 10, scale: 2
    t.decimal "sale_price", precision: 10, scale: 2
    t.integer "stock_quantity"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_care_products_on_user_id"
  end

  create_table "client_phones", force: :cascade do |t|
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.string "phone", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["client_id"], name: "index_client_phones_on_client_id"
    t.index ["user_id", "phone"], name: "index_client_phones_on_user_id_and_phone", unique: true
    t.index ["user_id"], name: "index_client_phones_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "birthday"
    t.datetime "created_at", null: false
    t.string "first_name", null: false
    t.string "hair_density"
    t.string "hair_length"
    t.string "hair_structure"
    t.string "hair_type"
    t.string "last_name"
    t.text "note"
    t.string "phone", null: false
    t.string "scalp_condition"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "phone"], name: "index_clients_on_user_id_and_phone", unique: true
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.integer "amount", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "note"
    t.date "spent_on", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_expenses_on_user_id"
  end

  create_table "formula_ingredients", force: :cascade do |t|
    t.string "amount", null: false
    t.string "brand"
    t.datetime "created_at", null: false
    t.integer "formula_product_id"
    t.integer "formula_step_id", null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.string "shade", null: false
    t.datetime "updated_at", null: false
    t.index ["formula_product_id"], name: "index_formula_ingredients_on_formula_product_id"
    t.index ["formula_step_id"], name: "index_formula_ingredients_on_formula_step_id"
  end

  create_table "formula_products", force: :cascade do |t|
    t.string "brand"
    t.string "category"
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "price_per_unit"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_formula_products_on_user_id"
  end

  create_table "formula_steps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "oxidant"
    t.string "section", null: false
    t.integer "service_note_id", null: false
    t.string "time"
    t.datetime "updated_at", null: false
    t.index ["service_note_id"], name: "index_formula_steps_on_service_note_id"
  end

  create_table "haircut_steps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "cut_type"
    t.string "elevation"
    t.string "instrument"
    t.text "notes"
    t.string "parting"
    t.integer "service_note_id", null: false
    t.datetime "updated_at", null: false
    t.string "zone"
    t.index ["service_note_id"], name: "index_haircut_steps_on_service_note_id"
  end

  create_table "service_note_services", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "service_id", null: false
    t.integer "service_note_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id"], name: "index_service_note_services_on_service_id"
    t.index ["service_note_id", "service_id"], name: "index_service_note_services_on_service_note_id_and_service_id", unique: true
    t.index ["service_note_id"], name: "index_service_note_services_on_service_note_id"
  end

  create_table "service_notes", force: :cascade do |t|
    t.integer "appointment_id"
    t.json "care_products", default: []
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.integer "main_photo_id"
    t.text "notes"
    t.integer "price"
    t.string "service_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["appointment_id"], name: "index_service_notes_on_appointment_id_unique", unique: true
    t.index ["client_id", "created_at"], name: "index_service_notes_on_client_id_and_created_at"
    t.index ["client_id"], name: "index_service_notes_on_client_id"
    t.index ["user_id"], name: "index_service_notes_on_user_id"
  end

  create_table "services", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "price", null: false
    t.string "service_type", default: "service", null: false
    t.string "subtype"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "category", "subtype"], name: "index_services_on_user_id_and_category_and_subtype", unique: true
    t.index ["user_id"], name: "index_services_on_user_id"
  end

  create_table "slot_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.time "end_time", null: false
    t.text "rule", null: false
    t.time "start_time", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "weekdays", null: false
    t.index ["user_id"], name: "index_slot_rules_on_user_id"
  end

  create_table "subscription_payments", force: :cascade do |t|
    t.integer "amount_minor", null: false
    t.json "callback_metadata"
    t.json "checkout_data"
    t.datetime "checkout_expires_at"
    t.datetime "created_at", null: false
    t.string "currency", default: "UAH", null: false
    t.string "merchant_account", null: false
    t.string "order_reference", null: false
    t.datetime "paid_at"
    t.datetime "period_end"
    t.datetime "period_start"
    t.string "plan", null: false
    t.datetime "processed_at"
    t.string "provider_status"
    t.string "reason_code"
    t.string "source", default: "purchase", null: false
    t.string "status", default: "pending", null: false
    t.integer "subscription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_account", "order_reference"], name: "index_subscription_payments_on_merchant_and_reference", unique: true
    t.index ["subscription_id"], name: "index_subscription_payments_on_subscription_id"
    t.check_constraint "amount_minor > 0", name: "subscription_payment_amount_is_positive"
    t.check_constraint "period_start IS NULL OR period_end IS NULL OR period_end > period_start", name: "subscription_payment_period_is_ordered"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.boolean "auto_renew", default: false, null: false
    t.datetime "cancelled_at"
    t.bigint "checkout_payment_id"
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.datetime "last_provider_paid_at"
    t.datetime "last_synced_at"
    t.json "management_intent"
    t.string "merchant_account"
    t.integer "next_amount_minor"
    t.string "next_plan"
    t.datetime "next_plan_starts_at"
    t.string "plan", default: "none", null: false
    t.string "provider_status"
    t.integer "renewal_amount_minor"
    t.string "source", default: "wayforpay", null: false
    t.string "status", default: "pending", null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "wayforpay_order_reference"
    t.index ["merchant_account", "wayforpay_order_reference"], name: "index_subscriptions_on_merchant_and_reference", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id", unique: true
    t.check_constraint "current_period_start IS NULL OR current_period_end IS NULL OR current_period_end > current_period_start", name: "subscription_period_is_ordered"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "phone", null: false
    t.string "plan_name"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role"
    t.date "subscription_expires_at"
    t.boolean "tos_agreement"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone"], name: "index_users_on_phone", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "wayforpay_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "fingerprint", null: false
    t.string "merchant_account", null: false
    t.json "metadata", null: false
    t.string "order_reference", null: false
    t.string "state", default: "received", null: false
    t.datetime "updated_at", null: false
    t.index ["fingerprint"], name: "index_wayforpay_events_on_fingerprint", unique: true
    t.index ["state", "created_at"], name: "index_wayforpay_events_on_state_and_created_at"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointment_services_relations", "appointments"
  add_foreign_key "appointment_services_relations", "services"
  add_foreign_key "appointments", "clients"
  add_foreign_key "appointments", "users"
  add_foreign_key "care_products", "users"
  add_foreign_key "client_phones", "clients"
  add_foreign_key "client_phones", "users"
  add_foreign_key "clients", "users"
  add_foreign_key "expenses", "users"
  add_foreign_key "formula_ingredients", "formula_steps"
  add_foreign_key "formula_products", "users"
  add_foreign_key "formula_steps", "service_notes"
  add_foreign_key "haircut_steps", "service_notes"
  add_foreign_key "service_note_services", "service_notes"
  add_foreign_key "service_note_services", "services"
  add_foreign_key "service_notes", "appointments"
  add_foreign_key "service_notes", "clients"
  add_foreign_key "service_notes", "users"
  add_foreign_key "services", "users"
  add_foreign_key "slot_rules", "users"
  add_foreign_key "subscription_payments", "subscriptions"
  add_foreign_key "subscriptions", "users"
end
