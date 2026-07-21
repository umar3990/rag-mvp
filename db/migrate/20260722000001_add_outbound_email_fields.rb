class AddOutboundEmailFields < ActiveRecord::Migration[8.1]
  def change
    # Per-org, not global -- each organization's n8n instance/workflow is
    # a separate thing to configure, symmetric to webhook_token on the
    # inbound side. Nullable: no real n8n instance exists to point at
    # yet, so these stay unset until an org is actually onboarded for
    # sending.
    add_column :organizations, :n8n_send_webhook_url, :string
    add_column :organizations, :n8n_send_webhook_secret, :string

    # Guards a retried send job against sending the same reply twice --
    # the same idempotency concern as the inbound side, just the other
    # direction.
    add_column :messages, :sent_at, :datetime
  end
end
