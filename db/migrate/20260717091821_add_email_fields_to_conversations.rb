class AddEmailFieldsToConversations < ActiveRecord::Migration[8.1]
  def up
    add_column :conversations, :source, :string
    add_column :conversations, :from_email, :string
    add_column :conversations, :gmail_thread_id, :string
    # Scoped to organization, not global -- defends against the
    # (unlikely but not impossible) case of two orgs' Gmail accounts
    # producing the same thread id, and matches how every other
    # cross-tenant lookup in this app is scoped.
    add_index :conversations, [ :organization_id, :gmail_thread_id ], unique: true

    # Email-originated conversations have no app user -- nothing to
    # attribute them to until a human approves a reply (Phase 5's
    # approval UI, not built yet).
    change_column_null :conversations, :user_id, true

    Conversation.reset_column_information
    Conversation.update_all(source: "web")
    change_column_null :conversations, :source, false
  end

  def down
    remove_column :conversations, :source
    remove_column :conversations, :from_email
    remove_column :conversations, :gmail_thread_id
    change_column_null :conversations, :user_id, false
  end
end
