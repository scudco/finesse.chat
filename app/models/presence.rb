# Heartbeat-based roster. Clients POST /presence every 30s on every
# transport; anyone seen within WINDOW counts as online.
class Presence < ApplicationRecord
  WINDOW = 90.seconds

  scope :online, -> { where(last_seen_at: WINDOW.ago..) }
end
