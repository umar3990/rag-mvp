class Document < ApplicationRecord
  ACCEPTED_CONTENT_TYPES = %w[ application/pdf text/plain ].freeze

  belongs_to :organization
  belongs_to :user, optional: true
  has_one_attached :file
  has_many :chunks, -> { order(:position) }, dependent: :destroy

  enum :status, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }, default: :pending

  # Live-updates the index page's row for this document over Turbo Streams
  # whenever it changes (partial: app/views/documents/_document.html.erb).
  broadcasts_to ->(document) { [ document.organization, :documents ] }
  # Tells any open show page for this document to smart-refresh itself
  # when it changes -- no bespoke partial needed for the detail view.
  broadcasts_refreshes

  validates :title, presence: true
  validate :file_is_present_and_acceptable

  # after_create_commit (not after_create) waits until the database
  # transaction actually commits before enqueuing -- otherwise the
  # background job could start looking for this record before it's
  # visible outside this transaction.
  after_create_commit :enqueue_processing

  private
    def file_is_present_and_acceptable
      unless file.attached?
        errors.add(:file, "must be attached")
        return
      end

      unless ACCEPTED_CONTENT_TYPES.include?(file.content_type)
        errors.add(:file, "must be a PDF or plain text file")
      end
    end

    def enqueue_processing
      DocumentProcessingJob.perform_later(self)
    end
end
