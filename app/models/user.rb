class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :organization
  has_many :documents, dependent: :nullify
  has_many :conversations, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
