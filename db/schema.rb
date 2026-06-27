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

ActiveRecord::Schema[8.1].define(version: 2026_06_27_120000) do
  create_table "hosts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "nominated_player_id"
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.index ["uuid"], name: "index_hosts_on_uuid", unique: true
  end

  create_table "logs", force: :cascade do |t|
    t.string "action", null: false
    t.string "actor_name"
    t.integer "actor_player_id"
    t.datetime "created_at", null: false
    t.json "data", default: {}
    t.integer "host_id", null: false
    t.integer "player_id"
    t.string "player_name"
    t.datetime "updated_at", null: false
    t.index ["host_id"], name: "index_logs_on_host_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "host_id", null: false
    t.string "name", null: false
    t.boolean "present", default: false, null: false
    t.integer "tickets", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index "host_id, LOWER(name)", name: "index_players_on_host_id_and_lower_name", unique: true
    t.index ["host_id"], name: "index_players_on_host_id"
    t.index ["uuid"], name: "index_players_on_uuid", unique: true
  end

  add_foreign_key "logs", "hosts"
  add_foreign_key "players", "hosts"
end
