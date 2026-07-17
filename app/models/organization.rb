class Organization < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :documents, dependent: :destroy
  has_many :chunks, dependent: :destroy
  has_many :conversations, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
