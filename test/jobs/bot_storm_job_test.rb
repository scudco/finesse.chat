require "test_helper"

class BotStormJobTest < ActiveSupport::TestCase
  test "creates the requested number of messages" do
    assert_difference "Message.count", 5 do
      BotStormJob.perform_now(count: 5)
    end
  end

  test "authors are drawn from the BOTS list with a numeric suffix" do
    BotStormJob.perform_now(count: 10)
    Message.last(10).each do |message|
      assert_match(/\A(#{BotStormJob::BOTS.join("|")})\d{2}\z/, message.author)
    end
  end

  test "content is drawn from the MESSAGES list" do
    BotStormJob.perform_now(count: 10)
    Message.last(10).each do |message|
      assert_includes BotStormJob::MESSAGES, message.content
    end
  end
end
