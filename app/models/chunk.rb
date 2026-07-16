class Chunk < ApplicationRecord
  belongs_to :document
  belongs_to :organization

  validates :content, presence: true
  validates :position, presence: true, uniqueness: { scope: :document_id }
end
