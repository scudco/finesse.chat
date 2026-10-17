require "test_helper"

class ClearMessagesJobTest < ActiveSupport::TestCase
  test "deletes all messages and presences" do
    Message.create!(author: "Alice", content: "one")
    Message.create!(author: "Bob", content: "two")
    Presence.create!(username: "Alice", last_seen_at: Time.current)
    ClearMessagesJob.perform_now
    assert_equal 0, Message.count
    assert_equal 0, Presence.count
  end

  test "no-ops gracefully when there are no messages" do
    Message.delete_all
    assert_nothing_raised { ClearMessagesJob.perform_now }
    assert_equal 0, Message.count
  end
end
