require "test_helper"

class FinesseBotTest < ActiveSupport::TestCase
  setup do
    @bot = FinesseBot.new
  end

  # /time
  test "/time returns a formatted timestamp" do
    result = @bot.send(:dispatch, "/time")
    assert_match(/🕐 \*\*\d{2}:\d{2}:\d{2}/, result)
  end

  # /meow
  test "/meow returns a cat fact" do
    result = @bot.send(:dispatch, "/meow")
    assert result.start_with?("🐱 ")
    assert FinesseBot::CAT_FACTS.include?(result.delete_prefix("🐱 "))
  end

  test "/🐱 is an alias for /meow" do
    result = @bot.send(:dispatch, "/🐱")
    assert result.start_with?("🐱 ")
  end

  # /wut
  test "/wut with a known acronym returns definition" do
    result = @bot.send(:dispatch, "/wut API")
    assert_equal "**API** — application programming interface", result
  end

  test "/wut is case-insensitive for the argument" do
    assert_equal @bot.send(:dispatch, "/wut api"), @bot.send(:dispatch, "/wut API")
  end

  test "/wut with no argument returns usage hint" do
    result = @bot.send(:dispatch, "/wut")
    assert_match(/needs an acronym/, result)
  end

  test "/wut with unknown acronym returns not-found message" do
    result = @bot.send(:dispatch, "/wut ZZZNOTREAL")
    assert_match(/no definition found/, result)
  end

  # unknown
  test "unknown command returns help listing" do
    result = @bot.send(:dispatch, "/explode")
    assert_match(/Unknown command/, result)
    assert_match(%r{/time}, result)
    assert_match(%r{/wut}, result)
  end

  # call
  test "call creates a bot message" do
    assert_difference "Message.count" do
      FinesseBot.call("/time")
    end
    assert_equal FinesseBot::BOT_AUTHOR, Message.last.author
  end
end
