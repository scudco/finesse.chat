class Message < ApplicationRecord
  validates :content, :author, presence: true
  validates :content, length: { maximum: 2000 }

  after_create_commit  -> { broadcast_append_to "chat" }
  after_update_commit  -> { broadcast_replace_to "chat" }
  after_destroy_commit -> { broadcast_remove_to "chat" }
end
