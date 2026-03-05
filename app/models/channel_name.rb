module ChannelName
  NAMES = %w[#general #botchat #humansonly #thisisfine #beep-boop #catfacts #iliketurtles #nobotsallowed #sendhelp].freeze
  CACHE_KEY = "channel_name"

  def self.current = Rails.cache.fetch(CACHE_KEY) { NAMES.first }

  def self.rotate!
    next_name = (NAMES - [current]).sample
    Rails.cache.write(CACHE_KEY, next_name)
    next_name
  end
end
