class Message < ApplicationRecord
  validates :content, :author, presence: true

  after_create_commit -> { broadcast_append_to "chat" }
end
