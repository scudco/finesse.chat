class ClearMessagesJob < ApplicationJob
  queue_as :default

  def perform
    Message.delete_all
    Turbo::StreamsChannel.broadcast_update_to(
      "chat",
      target: "messages",
      partial: "messages/empty_state"
    )
  end
end
