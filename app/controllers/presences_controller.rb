class PresencesController < ApplicationController
  # POST /presence  (turbo stream heartbeat, same on every transport)
  def create
    Presence.upsert({ username: current_username, last_seen_at: Time.current }, unique_by: :username)
    render turbo_stream: turbo_stream.replace("presence", partial: "presences/presence")
  end
end
