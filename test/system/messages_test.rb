require "application_system_test_case"

class MessagesTest < ApplicationSystemTestCase
  test "visiting the chat shows the page" do
    visit messages_url
    assert_selector "h1", text: "Finesse Chat"
  end

  test "sending a message displays it in the chat" do
    visit messages_url
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
