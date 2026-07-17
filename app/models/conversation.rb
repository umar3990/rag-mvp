class Conversation < ApplicationRecord
  belongs_to :organization
  # Optional -- an email-originated conversation has no app user until a
  # human approves a reply (Phase 5's approval UI). Only web-sourced
  # conversations (started from the chat UI) have one from creation.
  belongs_to :user, optional: true

  has_many :messages, -> { order(:created_at) }, dependent: :destroy

  enum :source, { web: "web", email: "email" }, default: :web

  validates :from_email, presence: true, if: :email?
  validates :gmail_thread_id, presence: true, if: :email?
  # No uniqueness validation here on purpose -- the DB's unique index on
  # (organization_id, gmail_thread_id) owns that invariant instead.
  # GmailWebhooksController relies on create_or_find_by!, which attempts
  # an insert and falls back to a find on a unique-index conflict; a
  # blocking validation here would raise before that fallback ever runs,
  # turning "an email arrived for an existing thread" -- the normal case,
  # not a race -- into a hard validation failure.
end
