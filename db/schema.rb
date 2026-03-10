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

ActiveRecord::Schema[8.1].define(version: 2026_03_10_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "findbug_alert_channels", force: :cascade do |t|
    t.string "channel_type", null: false
    t.text "config_data"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_type"], name: "index_findbug_alert_channels_on_channel_type"
    t.index ["enabled"], name: "index_findbug_alert_channels_on_enabled"
  end

  create_table "findbug_error_events", force: :cascade do |t|
    t.text "backtrace"
    t.jsonb "context", default: {}
    t.datetime "created_at", null: false
    t.string "environment"
    t.string "exception_class", null: false
    t.string "fingerprint", null: false
    t.datetime "first_seen_at"
    t.boolean "handled", default: false
    t.datetime "last_seen_at"
    t.text "message"
    t.integer "occurrence_count", default: 1
    t.bigint "project_id"
    t.string "release_version"
    t.jsonb "request_data", default: {}
    t.string "severity", default: "error"
    t.string "source"
    t.string "status", default: "unresolved"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_findbug_error_events_on_created_at"
    t.index ["exception_class", "created_at"], name: "index_findbug_error_events_on_exception_class_and_created_at"
    t.index ["exception_class"], name: "index_findbug_error_events_on_exception_class"
    t.index ["fingerprint"], name: "index_findbug_error_events_on_fingerprint"
    t.index ["last_seen_at"], name: "index_findbug_error_events_on_last_seen_at"
    t.index ["project_id", "fingerprint"], name: "idx_error_events_project_fingerprint"
    t.index ["project_id"], name: "index_findbug_error_events_on_project_id"
    t.index ["severity"], name: "index_findbug_error_events_on_severity"
    t.index ["status", "last_seen_at"], name: "index_findbug_error_events_on_status_and_last_seen_at"
    t.index ["status"], name: "index_findbug_error_events_on_status"
  end

  create_table "findbug_performance_events", force: :cascade do |t|
    t.datetime "captured_at"
    t.jsonb "context", default: {}
    t.datetime "created_at", null: false
    t.float "db_time_ms", default: 0.0
    t.float "duration_ms", null: false
    t.string "environment"
    t.string "format"
    t.boolean "has_n_plus_one", default: false
    t.jsonb "n_plus_one_queries", default: []
    t.bigint "project_id"
    t.integer "query_count", default: 0
    t.string "release_version"
    t.string "request_method"
    t.string "request_path"
    t.jsonb "slow_queries", default: []
    t.integer "status"
    t.string "transaction_name", null: false
    t.string "transaction_type", default: "request"
    t.datetime "updated_at", null: false
    t.integer "view_count", default: 0
    t.float "view_time_ms", default: 0.0
    t.index ["captured_at"], name: "idx_fb_perf_captured_at"
    t.index ["duration_ms"], name: "idx_fb_perf_duration"
    t.index ["has_n_plus_one"], name: "idx_fb_perf_n_plus_one"
    t.index ["project_id"], name: "index_findbug_performance_events_on_project_id"
    t.index ["transaction_name", "captured_at"], name: "idx_fb_perf_txn_captured"
    t.index ["transaction_name"], name: "idx_fb_perf_txn_name"
    t.index ["transaction_type"], name: "idx_fb_perf_txn_type"
  end

  create_table "findbug_projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "dsn_key", null: false
    t.string "name", null: false
    t.string "platform", default: "ruby"
    t.datetime "updated_at", null: false
    t.index ["dsn_key"], name: "index_findbug_projects_on_dsn_key", unique: true
    t.index ["name"], name: "index_findbug_projects_on_name"
  end

  add_foreign_key "findbug_error_events", "findbug_projects", column: "project_id"
  add_foreign_key "findbug_performance_events", "findbug_projects", column: "project_id"
end
