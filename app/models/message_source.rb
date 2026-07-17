class MessageSource < ApplicationRecord
  belongs_to :message
  belongs_to :document
end
