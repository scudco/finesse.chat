# Flood the chat stream with messages to test SSE throughput.
#
# Usage:
#   bin/rails runner script/flood_chat.rb
#
# Options (env vars):
#   RATE=5      messages per second  (default: 3)
#   COUNT=500   stop after N messages (default: runs until Ctrl-C)

rate  = ENV.fetch("RATE",  3).to_f
count = ENV["COUNT"]&.to_i

AUTHORS = %w[FloodBot StreamBot RaceBot EchoBot PulseBot WaveBot].freeze

LINES = [
  "message %d — SSE is holding up fine",
  "message %d — no WebSocket in sight",
  "message %d — Go server polling away",
  "message %d — Turbo appending live",
  "message %d — still here, still streaming",
  "message %d — #{Time.now.strftime("%H:%M:%S")} on the clock",
].freeze

puts "Flooding at #{rate} msg/s#{count ? ", stopping after #{count}" : " (Ctrl-C to stop)"}…"

i = 0
loop do
  break if count && i >= count

  Message.create!(
    author:  AUTHORS.sample,
    content: LINES.sample % i
  )

  i += 1
  print "\r  #{i} sent"
  $stdout.flush

  sleep(1.0 / rate)
end

puts "\nDone — #{i} messages sent."
