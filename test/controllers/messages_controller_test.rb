require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @message = messages(:one)
  end

  test "index renders successfully" do
    get messages_url
    assert_response :success
  end

  test "create saves message and returns turbo stream" do
    assert_difference "Message.count" do
      post messages_url,
        params: { message: { content: "hello" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end

  test "create with blank content does not save" do
    assert_no_difference "Message.count" do
      post messages_url,
        params: { message: { content: "" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end

  test "create with slash command creates exactly one message and it is from FinesseBot" do
    assert_difference "Message.count", 1 do
      post messages_url,
        params: { message: { content: "/time" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_equal FinesseBot::BOT_AUTHOR, Message.last.author
    assert_response :success
  end

  test "update replaces message content" do
    post messages_url,
      params: { message: { content: "original" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    message = Message.last

    patch message_url(message),
      params: { message: { content: "updated" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "updated", message.reload.content
  end

  test "destroy removes message" do
    post messages_url,
      params: { message: { content: "to be deleted" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    message = Message.last

    assert_difference "Message.count", -1 do
      delete message_url(message),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end
end
