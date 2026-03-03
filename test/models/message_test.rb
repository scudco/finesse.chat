require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "valid with author and content" do
    assert Message.new(author: "Alice", content: "hello").valid?
  end

  test "invalid without author" do
    assert_not Message.new(content: "hello").valid?
  end

  test "invalid without content" do
    assert_not Message.new(author: "Alice").valid?
  end

  test "invalid when content exceeds 2000 characters" do
    assert_not Message.new(author: "Alice", content: "x" * 2001).valid?
  end

  test "valid at exactly 2000 characters" do
    assert Message.new(author: "Alice", content: "x" * 2000).valid?
  end
end
