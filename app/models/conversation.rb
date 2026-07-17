class Conversation < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  has_many :messages, -> { order(:created_at) }, dependent: :destroy
end
