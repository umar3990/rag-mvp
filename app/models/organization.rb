class Organization < ApplicationRecord
  # Identifies + authenticates inbound Gmail webhook requests in one step
  # (POST /webhooks/gmail/:webhook_token) -- random and unguessable, same
  # role a per-account webhook secret plays in Stripe/GitHub. Rails'
  # has_secure_token both generates it on create and gives a
  # regenerate_webhook_token! method for rotating a leaked one.
  has_secure_token :webhook_token

  has_many :users, dependent: :restrict_with_error
  has_many :documents, dependent: :destroy
  has_many :chunks, dependent: :destroy
  has_many :conversations, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
