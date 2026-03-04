require "test_helper"

class SlashCommandTest < ActiveSupport::TestCase
  test "match? detects leading slash" do
    assert SlashCommand.match?("/time")
    assert SlashCommand.match?("  /time")
  end

  test "match? rejects plain messages" do
    assert_not SlashCommand.match?("hello")
    assert_not SlashCommand.match?("")
    assert_not SlashCommand.match?(nil)
  end

  test "me? is true for /me command" do
    assert SlashCommand.new("/me waves", author: "Alice").me?
  end

  test "me? is false for other commands" do
    assert_not SlashCommand.new("/time", author: "Alice").me?
    assert_not SlashCommand.new("/wut API", author: "Alice").me?
  end

  test "bot_input returns input for non-/me commands" do
    cmd = SlashCommand.new("/wut API", author: "Alice")
    assert_equal "/wut API", cmd.bot_input
  end

  test "bot_input returns nil for /me" do
    cmd = SlashCommand.new("/me waves", author: "Alice")
    assert_nil cmd.bot_input
  end

  test "message returns nil for non-/me commands" do
    cmd = SlashCommand.new("/time", author: "Alice")
    assert_nil cmd.message
  end

  test "message formats /me as italic action" do
    cmd = SlashCommand.new("/me waves hello", author: "Alice")
    assert_equal "_\\* Alice waves hello_", cmd.message.content
    assert_equal "Alice", cmd.message.author
  end

  test "message handles /me with no action" do
    cmd = SlashCommand.new("/me", author: "Alice")
    assert_equal "_\\* Alice _", cmd.message.content
  end
end
