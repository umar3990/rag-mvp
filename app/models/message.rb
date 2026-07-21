class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :message_sources, dependent: :destroy
  has_many :source_documents, through: :message_sources, source: :document

  enum :role, { user: "user", assistant: "assistant" }
  # Nil for anything that isn't an email-sourced assistant reply -- web
  # chat replies show directly to the user asking, so review doesn't
  # apply. enum on a nullable column works fine: nil stays nil, and only
  # a non-nil value is validated against the allowed set.
  enum :review_status, { pending: "pending", approved: "approved", rejected: "rejected" }, prefix: true

  validates :content, presence: true
  # DB unique index is what actually prevents a race between concurrent
  # webhook deliveries for the same email; this just turns that into a
  # normal validation error instead of a raw PG::UniqueViolation when two
  # requests do land far enough apart to both reach validation.
  validates :gmail_message_id, uniqueness: true, allow_nil: true

  # The customer's question this reply answers -- ordered by id, not
  # created_at, since two messages created in the same request/job can
  # share a timestamp down to the second.
  def question
    conversation.messages.user.where(id: ...id).order(:id).last
  end
end
