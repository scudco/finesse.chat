require "csv"

class FinesseBotJob < ApplicationJob
  BOT_AUTHOR  = "FinesseBot"
  CAT_FACTS   = File.readlines(Rails.root.join("db/catfacts.txt"), chomp: true).freeze
  DOG_FACTS   = File.readlines(Rails.root.join("db/dogfacts.txt"), chomp: true).freeze
  ACRONYMS    = CSV.read(Rails.root.join("db/acronyms.tsv"), col_sep: "\t").to_h.freeze

  def perform(input, invoked_by: nil)
    content = dispatch(input.strip)
    Message.create!(author: BOT_AUTHOR, content: content, invoked_by:) if content
  end

  private

  def dispatch(input)
    command, arg = input.split(" ", 2)
    case command.downcase
    when "/help"        then help
    when "/time"        then time
    when "/woof", "/🐶" then dog_fact
    when "/meow", "/🐱" then cat_fact
    when "/wut"         then wut(arg)
    else                     unknown(command)
    end
  end

  def time
    "🕐 **#{Time.current.strftime("%H:%M:%S %Z")}**"
  end

  def unknown(command)
    "Unknown command: `#{command}`\n\n#{help}"
  end

  def help
    <<~MSG
    Available commands:

    - `/time`
    - `/meow`
    - `/woof`
    - `/wut <acronym>`
    - `/me <action>`
    MSG
  end

  def dog_fact
    "🐶 #{DOG_FACTS.sample}"
  end

  def cat_fact
    "🐱 #{CAT_FACTS.sample}"
  end

  def wut(acronym)
    key = acronym.to_s.strip.upcase

    return "`/wut` needs an acronym — e.g. `/wut API`" if acronym.blank?
    return "no definition found for `#{acronym.strip}` 🤷" unless ACRONYMS.key?(key)

    "**#{key}** — #{ACRONYMS[key]}"
  end
end
