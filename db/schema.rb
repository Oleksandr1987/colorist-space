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

ActiveRecord::Schema[8.1].define(version: 2026_05_08_155808) do
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

  create_table "client_phones", force: :cascade do |t|
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.string "phone", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_client_phones_on_client_id"
    t.index ["phone"], name: "index_client_phones_on_phone", unique: true
  end

  create_table "clients", force: :cascade do |t|
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
    t.integer "formula_step_id", null: false
    t.string "shade", null: false
    t.datetime "updated_at", null: false
    t.index ["formula_step_id"], name: "index_formula_ingredients_on_formula_step_id"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointment_services_relations", "appointments"
  add_foreign_key "appointment_services_relations", "services"
  add_foreign_key "appointments", "clients"
  add_foreign_key "appointments", "users"
  add_foreign_key "client_phones", "clients"
  add_foreign_key "clients", "users"
  add_foreign_key "expenses", "users"
  add_foreign_key "formula_ingredients", "formula_steps"
  add_foreign_key "formula_steps", "service_notes"
  add_foreign_key "service_note_services", "service_notes"
  add_foreign_key "service_note_services", "services"
  add_foreign_key "service_notes", "appointments"
  add_foreign_key "service_notes", "clients"
  add_foreign_key "service_notes", "users"
  add_foreign_key "services", "users"
  add_foreign_key "slot_rules", "users"
end
