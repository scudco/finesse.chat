module MessagesHelper
  # Generates the URL for the Go SSE server for a given set of streamables,
  # using the same signed stream name that broadcast_append_to writes to the DB.
  def sse_stream_url(*streamables)
    # SolidCable stores the raw stream name, not the signed variant.
    # The stream name for broadcast_append_to("chat") is just "chat".
    channel = streamables.flatten.join(":")
    host    = ENV.fetch("SSE_HOST") { "#{request.scheme}://#{request.host}:4000" }
    "#{host}/sse?channel=#{CGI.escape(channel)}"
  end
end
