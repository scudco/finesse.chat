require "application_system_test_case"

class MessagesTest < ApplicationSystemTestCase
  def setup
    visit root_url
    click_button "Start chatting"
  end

  test "visiting the chat shows the page" do
    assert_selector "h1", text: ChannelName::NAMES.first
  end

  test "sending a message displays it in the chat" do
    fill_in "message[content]", with: "hello system test"
    click_button "Send"
    assert_text "hello system test"
  end

  test "empty state is shown when there are no messages" do
    Message.delete_all
    visit messages_url
    assert_selector ".chat-empty-state"
  end
end
