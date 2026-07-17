class AddWebhookTokenToOrganizations < ActiveRecord::Migration[8.1]
  def up
    add_column :organizations, :webhook_token, :string
    add_index :organizations, :webhook_token, unique: true

    # Backfill existing organizations -- has_secure_token (added to the
    # model alongside this migration) only generates a token on create,
    # so rows that already exist need one assigned by hand before the
    # NOT NULL constraint below can be added.
    Organization.reset_column_information
    Organization.find_each { |org| org.update_column(:webhook_token, SecureRandom.base58(24)) }

    change_column_null :organizations, :webhook_token, false
  end

  def down
    remove_column :organizations, :webhook_token
  end
end
