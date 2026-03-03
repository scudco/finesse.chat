require 'net/http'

class FinesseBotJob < ApplicationJob
  BOT_AUTHOR = "FinesseBot"

  def perform(message)
    content = dispatch(message.content.strip)
    Message.create!(author: BOT_AUTHOR, content: content) if content
  end

  private

  def dispatch(input)
    command, arg = input.split(" ", 2)
    case command.downcase
    when "/time"
      "🕐 **#{Time.current.strftime("%H:%M:%S %Z")}**"
    when "/catfact", "/meow"
      cat_fact
    when "/wtf"
      return "`/wtf` needs an acronym — e.g. `/wtf API`" if arg.blank?
      wtf(arg.strip)
    else
      "Unknown command: `#{command}`\n\nAvailable commands:\n- `/time`\n- `/catfact`\n- `/wtf <acronym>`"
    end
  end

  def cat_fact
    data = get_json("https://catfact.ninja/fact")
    "🐱 #{data["fact"]}"
  rescue => e
    logger.error("FinesseBotJob /catfact failed: #{e.class}: #{e.message}")
    "failed to fetch cat fact 😿"
  end

  def wtf(acronym)
    data = get_json("https://api.urbandictionary.com/v0/define?term=#{URI.encode_www_form_component(acronym)}")
    entry = data["list"]&.first
    return "no definition found for `#{acronym}` 🤷" unless entry
    "**#{acronym.upcase}** — #{entry["definition"].truncate(300)}"
  rescue => e
    logger.error("FinesseBotJob /wtf '#{acronym}' failed: #{e.class}: #{e.message}")
    "couldn't look up `#{acronym}` 😬"
  end

  def get_json(url)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                   open_timeout: 5, read_timeout: 5) do |http|
      http.get(uri.request_uri, "User-Agent" => "Finesse/1.0")
    end
    JSON.parse(response.body)
  end
end
