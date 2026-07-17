class Message < ApplicationRecord
  belongs_to :conversation
  has_many :message_sources, dependent: :destroy
  has_many :source_documents, through: :message_sources, source: :document

  enum :role, { user: "user", assistant: "assistant" }

  validates :content, presence: true
end
