class Message < ApplicationRecord
  belongs_to :conversation
  has_many :message_sources, dependent: :destroy
  has_many :source_documents, through: :message_sources, source: :document

  enum :role, { user: "user", assistant: "assistant" }

  validates :content, presence: true
  # DB unique index is what actually prevents a race between concurrent
  # webhook deliveries for the same email; this just turns that into a
  # normal validation error instead of a raw PG::UniqueViolation when two
  # requests do land far enough apart to both reach validation.
  validates :gmail_message_id, uniqueness: true, allow_nil: true
end
