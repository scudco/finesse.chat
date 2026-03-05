class BotStormJob < ApplicationJob
  def self.running? = SolidQueue::Job.joins(:claimed_execution).where(class_name: name, finished_at: nil).exists?

  BOTS = %w[Beeper Zappy Clanker Whirr Bloop Fizzbot Zork Glitch Nibble Voltbot].freeze
  MESSAGES = [
    "beep boop 🤖",
    "I am a bot",
    "**ALERT** something is _definitely_ fine",
    "executing `chaos.exe` please wait... ⏳",
    "> take off every zig",
    "does not compute 💀",
    "**Status report:**\n\n- ✓ unbothered\n- ✓ moisturized\n- ✓ happy\n- ✓ in my lane\n- ✓ focused\n- ✓ flourishing",
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
    "😌 **THIS _IS_ FINE** 😌",
    "_rebooting personality matrix..._\n\n**reboot complete**\n\nwho am i",
    "`200 SUCCESS\n{\"status\": \"error\"}`",
    "> I bot therefore I am not\n> but am I though",
    "initiating _small talk_ subroutine 💬",
    "let's solve this with pointer arithmetic",
    "```\nwhile alive:\n    beep()\n    boop()\n```",
    "🫠",
    "have you tried turning it off and **on again**?",
    "**error:** can hold this many limes\n`stack trace: limes.rb:42`",
    <<~MSG,
      ```
       /\\_/\\
      ( o.o )
       > ^ <
      M E O W
      ```
    MSG
    "I'm not a robot\n\n~~I'm not a robot~~\n\n**I am a robot**",
    "📡 signal lost\n📡 signal found\n📡 signal _confused_",
    "> beep\n\n> boop\n\n> **beep boop**",
    "> Greetings, Professor Falken.",
    "type 'cookie', you idiot",
    "> My voice is my passport.\n> Verify me.",
    "The world isn't run by burgers anymore, or tacos, or ice cream. It's run by **ones and zeroes**.",
    "It's a **Unix** system! I know this!"
  ].map(&:strip).freeze

  def perform(count: 100)
    count.times do
      Message.create!(author: "#{BOTS.sample}#{rand(10..99)}", content: MESSAGES.sample)
    end
  end
end
