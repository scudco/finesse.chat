class BotStormJob < ApplicationJob
  BOTS = %w[Beeper Zappy Clank Whirr Bloop Fizzbot Zork Glitch Nibble Voltron].freeze
  MESSAGES = [
    "beep boop", "I am a bot", "01001000 01101001", "PROCESSING...",
    "have you tried turning it off and on again?", "executing chaos.exe",
    "bzzzt", "all your base are belong to us", "does not compute",
    "rebooting personality matrix", "404: chill not found",
    "initiating small talk subroutine", "I have no feelings about this",
    "🤖", "this is fine", "pizza? pizza.", "beep.", "boop.",
    "I'm not a robot... wait", "error: too many vibes",
  ].freeze

  def perform(count: 100)
    count.times do
      Message.create!(author: "#{BOTS.sample}#{rand(10..99)}", content: MESSAGES.sample)
      sleep 0.02
    end
  end
end
