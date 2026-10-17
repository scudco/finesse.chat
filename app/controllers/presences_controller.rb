class PresencesController < ApplicationController
  before_action { head :not_found unless Feature.enabled?(:presence, session) }

  # POST /presence  (turbo stream heartbeat, same on every transport)
  def create
    joined = !Presence.online.exists?(username: current_username)
    Presence.upsert({ username: current_username, last_seen_at: Time.current }, unique_by: :username)
    # Push joins to WS and SSE clients at once. Polling clients and leaves
    # still wait for the next heartbeat.
    Turbo::StreamsChannel.broadcast_replace_to("chat", target: "presence", partial: "presences/presence") if joined
    render turbo_stream: turbo_stream.replace("presence", partial: "presences/presence")
  end
end
