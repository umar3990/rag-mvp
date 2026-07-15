class Document < ApplicationRecord
  belongs_to :organization
  belongs_to :user, optional: true

  validates :title, presence: true
end
