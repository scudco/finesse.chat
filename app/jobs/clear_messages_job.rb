class ClearMessagesJob < ApplicationJob
  queue_as :default

  def perform
    Message.delete_all
    new_name = ChannelName.rotate!
    Turbo::StreamsChannel.broadcast_update_to("chat", target: "channel_name", html: new_name)
    Turbo::StreamsChannel.broadcast_update_to(
      "chat",
      target: "messages",
      partial: "messages/empty_state"
    )
  end
end
