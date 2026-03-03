require "csv"

class FinesseBotJob < ApplicationJob
  BOT_AUTHOR  = "FinesseBot"
  CAT_FACTS   = File.readlines(Rails.root.join("db/catfacts.txt"), chomp: true).freeze
  ACRONYMS    = CSV.read(Rails.root.join("db/acronyms.tsv"), col_sep: "\t").to_h.freeze

  def perform(input, invoked_by: nil)
    content = dispatch(input.strip)
    Message.create!(author: BOT_AUTHOR, content: content, invoked_by:) if content
  end

  private

  def dispatch(input)
    command, arg = input.split(" ", 2)
    case command.downcase
    when "/time"        then time
    when "/meow", "/🐱" then cat_fact
    when "/wtf"         then wtf(arg)
    else                     unknown(command)
    end
  end

  def time
    "🕐 **#{Time.current.strftime("%H:%M:%S %Z")}**"
  end

  def unknown(command)
    <<~MSG
    Unknown command: `#{command}`

    Available commands:
    - `/time`
    - `/meow`
    - `/wtf <acronym>`
    - `/me <action>`
    MSG
  end

  def cat_fact
    "🐱 #{CAT_FACTS.sample}"
  end

  def wtf(acronym)
    key = acronym.to_s.strip.upcase

    return "`/wtf` needs an acronym — e.g. `/wtf API`" if acronym.blank?
    return "no definition found for `#{acronym.strip}` 🤷" unless ACRONYMS.key?(key)

    "**#{key}** — #{ACRONYMS[key]}"
  end
end
