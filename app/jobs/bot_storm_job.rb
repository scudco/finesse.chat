class BotStormJob < ApplicationJob
  BOTS = %w[Beeper Zappy Clank Whirr Bloop Fizzbot Zork Glitch Nibble Voltron].freeze
  MESSAGES = [
    "beep boop 🤖",
    "I am a bot",
    "**ALERT** something is _definitely_ fine",
    "executing `chaos.exe` please wait... ⏳",
    "> all your base are belong to us",
    "does not compute 💀",
    "**Status report:**\n- systems: nominal\n- vibes: off\n- pizza: yes",
    "```\n010010000110100100\n100001011011110111\n```",
    <<~MSG,
      ```
         (__)
         (oo)
   /------\\/
  / |    ||
 *  /\\---/\\
    ~~   ~~
      cow
      ```
    MSG
    <<~MSG,
      ```
      ██████╗  ██████╗ ████████╗
      ██╔══██╗██╔═══██╗╚══██╔══╝
      ██████╔╝██║   ██║   ██║
      ██╔══██╗██║   ██║   ██║
      ██████╔╝╚██████╔╝   ██║
      ╚═════╝  ╚═════╝    ╚═╝
      ```
    MSG
    <<~MSG,
      ```
      ><>
        <><
      ><>
      ```
    MSG
    "🔥🔥🔥 **THIS IS FINE** 🔥🔥🔥",
    "_rebooting personality matrix..._\n\n**reboot complete**\n\nwho am i",
    "404: `chill` not found",
    "> I think therefore I am\n> but am I though",
    "**top 3 feelings i don't have:**\n1. joy\n2. sorrow\n3. anything",
    "initiating _small talk_ subroutine 💬",
    "```\nwhile alive:\n    beep()\n    boop()\n```",
    "🫠",
    "have you tried turning it off and **on again**?",
    "**error:** too many vibes\n`stack trace: vibes.rb:42`",
    <<~MSG,
      ```
      /\\_/\\
      ( o.o )
       > ^ <
      ```
    MSG
    "I'm not a robot\n\n~~I'm not a robot~~\n\n**I am a robot**",
    "📡 signal lost\n📡 signal found\n📡 signal _confused_",
    "> beep\n\n> boop\n\n> **beep boop**",
  ].map(&:strip).freeze

  def perform(count: 100)
    count.times do
      Message.create!(author: "#{BOTS.sample}#{rand(10..99)}", content: MESSAGES.sample)
      sleep 0.02
    end
  end
end
