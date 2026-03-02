class Message < ApplicationRecord
  validates :content, :author, presence: true
  validates :content, length: { maximum: 2000 }

  after_create_commit -> { broadcast_append_to "chat" }
end
