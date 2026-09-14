# frozen_string_literal: true

# Loaded into the in-memory database at boot (see test/integration_helper.rb).
# The ActionMailbox and Active Storage tables are the ones their generators
# install; conversations and messages are a host app's, written to satisfy
# the mailbox hooks with as little as possible.
ActiveRecord::Schema.define do
  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.string "message_id", null: false
    t.string "message_checksum", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "message_id", "message_checksum" ], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index [ "key" ], unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index [ "blob_id" ]
    t.index [ "record_type", "record_id", "name", "blob_id" ], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index [ "blob_id", "variation_digest" ], unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.string "subject", null: false
    t.string "customer_email", null: false
    t.string "support_address", null: false
    t.string "mail_token", null: false
    t.string "opening_message_id"
    t.datetime "handed_off_at"
    t.string "handoff_reason"
    t.timestamps
    t.index [ "mail_token" ], unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.references "conversation", null: false
    t.string "role", null: false
    t.text "body", null: false
    t.string "message_id"
    t.boolean "draft", default: false, null: false
    t.datetime "delivered_at"
    t.timestamps
    t.index [ "message_id" ]
  end
end
