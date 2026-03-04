require "test_helper"

class FinesseBotJobTest < ActiveSupport::TestCase
  setup do
    @job = FinesseBotJob.new
  end

  # /time
  test "/time returns a formatted timestamp" do
    result = @job.send(:dispatch, "/time")
    assert_match(/🕐 \*\*\d{2}:\d{2}:\d{2}/, result)
  end

  # /meow
  test "/meow returns a cat fact" do
    result = @job.send(:dispatch, "/meow")
    assert result.start_with?("🐱 ")
    assert FinesseBotJob::CAT_FACTS.include?(result.delete_prefix("🐱 "))
  end

  test "/🐱 is an alias for /meow" do
    result = @job.send(:dispatch, "/🐱")
    assert result.start_with?("🐱 ")
  end

  # /wut
  test "/wut with a known acronym returns definition" do
    result = @job.send(:dispatch, "/wut API")
    assert_equal "**API** — application programming interface", result
  end

  test "/wut is case-insensitive for the argument" do
    assert_equal @job.send(:dispatch, "/wut api"), @job.send(:dispatch, "/wut API")
  end

  test "/wut with no argument returns usage hint" do
    result = @job.send(:dispatch, "/wut")
    assert_match(/needs an acronym/, result)
  end

  test "/wut with unknown acronym returns not-found message" do
    result = @job.send(:dispatch, "/wut ZZZNOTREAL")
    assert_match(/no definition found/, result)
  end

  # unknown
  test "unknown command returns help listing" do
    result = @job.send(:dispatch, "/explode")
    assert_match(/Unknown command/, result)
    assert_match(%r{/time}, result)
    assert_match(%r{/wut}, result)
  end

  # perform
  test "perform creates a bot message" do
    assert_difference "Message.count" do
      FinesseBotJob.perform_now("/time")
    end
    assert_equal FinesseBotJob::BOT_AUTHOR, Message.last.author
  end
end
