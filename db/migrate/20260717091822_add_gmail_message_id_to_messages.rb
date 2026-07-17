class AddGmailMessageIdToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :gmail_message_id, :string
    # The idempotency key itself -- Gmail's Message-Id header is globally
    # unique and stable per email. A unique index (not just an
    # application-level check) is what actually prevents a race between
    # two webhook deliveries for the same email processed concurrently.
    # Postgres allows multiple NULLs under a unique index, so this
    # doesn't constrain web-sourced messages, which never set it.
    add_index :messages, :gmail_message_id, unique: true
  end
end
