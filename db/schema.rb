# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20141123081409) do

  create_table "jobs", force: true do |t|
    t.string   "gene_name"
    t.integer  "quality_threshold",         default: 33
    t.string   "description"
    t.boolean  "paused",                    default: false
    t.boolean  "awaiting_download",         default: false
    t.string   "ensembl"
    t.integer  "ensembl_pid"
    t.datetime "ensembl_lock",              default: '1970-01-01 00:00:00'
    t.datetime "ensembl_last_retry",        default: '1970-01-01 00:00:00'
    t.integer  "ensembl_retries",           default: 0
    t.string   "ensembl_last_error"
    t.boolean  "ensembl_ok",                default: false
    t.boolean  "ensembl_failed",            default: false
    t.boolean  "genomics_ensembl",          default: false
    t.string   "genomics_url"
    t.integer  "genomics_pid"
    t.datetime "genomics_lock",             default: '1970-01-01 00:00:00'
    t.datetime "genomics_last_retry",       default: '1970-01-01 00:00:00'
    t.integer  "genomics_retries",          default: 0
    t.string   "genomics_last_error"
    t.boolean  "genomics_ok",               default: false
    t.boolean  "genomics_failed",           default: false
    t.string   "reads_last_error"
    t.boolean  "all_reads_ok",              default: false
    t.boolean  "some_reads_failed",         default: false
    t.datetime "downloads_completed_at"
    t.boolean  "awaiting_dispatch",         default: false
    t.integer  "processing_dispatch_pid"
    t.datetime "processing_dispatch_lock",  default: '1970-01-01 00:00:00'
    t.datetime "processing_dispatched_at",  default: '1970-01-01 00:00:00'
    t.string   "processing_dispatch_error"
    t.boolean  "processing_dispatch_ok",    default: false
    t.string   "processing_metrics"
    t.string   "processing_error"
    t.integer  "server_id"
    t.integer  "user_id"
    t.integer  "organism_id"
    t.integer  "result_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "jobs", ["result_id"], name: "index_jobs_on_result_id"

  create_table "jobs_reads", force: true do |t|
    t.integer  "job_id"
    t.string   "url"
    t.integer  "retries",    default: 0
    t.datetime "last_retry", default: '1970-01-01 00:00:00'
    t.integer  "pid"
    t.datetime "lock",       default: '1970-01-01 00:00:00'
    t.boolean  "ok",         default: false
    t.boolean  "failed",     default: false
    t.string   "last_error"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "organisms", force: true do |t|
    t.string  "name"
    t.string  "ensembl_id"
    t.string  "description"
    t.boolean "enabled",     default: true
  end

  create_table "processing_status", force: true do |t|
    t.string   "key"
    t.text     "value"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "results", force: true do |t|
    t.string   "json"
    t.string   "gene_name"
    t.string   "description"
    t.string   "ref_sequence"
    t.datetime "validated"
    t.integer  "user_id"
    t.integer  "server_id"
    t.integer  "job_id"
    t.integer  "organism_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "results", ["gene_name", "organism_id"], name: "index_results_on_gene_name_and_organism_id", unique:false #unique: true
  add_index "results", ["job_id"], name: "index_results_on_job_id", unique: true

  create_table "servers", force: true do |t|
    t.integer  "priority"
    t.string   "name",                                              null: false
    t.string   "host",                                              null: false
    t.string   "port"
    t.string   "username",                                          null: false
    t.string   "password"
    t.string   "ssh_proxy_command"
    t.string   "working_dir"
    t.string   "pintron_path"
    t.boolean  "use_callback",      default: true
    t.string   "callback_url"
    t.boolean  "local_network",     default: true
    t.boolean  "enabled",           default: true
    t.datetime "check_lock",        default: '1970-01-01 00:00:00'
    t.datetime "check_last_at",     default: '1970-01-01 00:00:00'
    t.integer  "check_pid"
    t.string   "last_check_error"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "servers", ["name"], name: "index_servers_on_name", unique: true
  add_index "servers", ["priority"], name: "index_servers_on_priority", unique: true

  create_table "settings", force: true do |t|
    t.string   "key"
    t.text     "value"
    t.string   "name"
    t.string   "description"
    t.string   "html_field_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "user_history", force: true do |t|
    t.integer  "admin_id"
    t.integer  "subject_id"
    t.string   "message"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: true do |t|
    t.string   "nickname"
    t.string   "password_digest"
    t.string   "email"
    t.boolean  "admin",      default: false
    t.boolean  "enabled",    default: true
    t.integer  "max_fs",     default: -1
    t.integer  "max_cput",   default: -1
    t.integer  "max_ql",     default: -1
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["nickname"], name: "index_users_on_nickname", unique: true

end
