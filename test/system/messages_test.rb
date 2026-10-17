require "application_system_test_case"

class MessagesTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  test "visiting the chat shows the page" do
    join_chat
    assert_selector "h1", text: ChannelName::NAMES.first
  end

  test "sending a message displays it in the chat" do
    join_chat
    send_message "hello system test"
  end

  test "empty state is shown when there are no messages" do
    Message.delete_all
    join_chat
    assert_selector ".chat-empty-state"
  end

  test "editing an own message updates it in place" do
    join_chat
    send_message "first draft"

    # ArrowUp in the empty input opens the editor for your last own message.
    find("textarea[name='message[content]']").send_keys :arrow_up
    find("#messages [data-message-target=editor] textarea:not([hidden])", visible: :all).set("final cut")
    click_button "Save"

    assert_text "final cut"
    assert_no_text "first draft"
  end

  test "deleting an own message removes it" do
    join_chat
    send_message "doomed message"

    hover_message("doomed message").click_link "Delete"

    assert_no_text "doomed message"
  end

  test "slash commands trigger a bot reply" do
    join_chat
    fill_in "message[content]", with: "/meow"
    click_button "Send"
    assert_text FinesseBot::BOT_AUTHOR
  end

  test "scrolling to the top loads older messages" do
    60.times { |i| Message.create!(author: "Seeder", content: "seed #{i + 1} of 60") }
    join_chat

    assert_text "seed 60 of 60"
    assert_no_text "seed 1 of 60" # only the latest 50 are rendered

    execute_script "document.querySelector('[data-chat-target=scroll]').scrollTop = 0"
    assert_text "seed 1 of 60"
  end

  test "refreshing the username assigns a new one" do
    join_chat
    before = find("#current-username").text
    click_button "New username"
    assert_no_selector "#current-username", exact_text: before
    assert_selector "#current-username"
  end

  test "bot storm button enqueues the job and starts its cooldown" do
    join_chat
    stub_singleton BotStormJob, :running?, false do
      click_button "Bot Storm"
      assert_selector ".btn-storm[disabled]"
      deadline = Time.now + Capybara.default_max_wait_time
      sleep 0.1 until enqueued_jobs.any? { |job| job["job_class"] == "BotStormJob" } || Time.now > deadline
      assert_enqueued_jobs 1, only: BotStormJob
    end
  end

  private

  # CSS-hover reveal is pointer-position sensitive: date separators insert
  # ~50ms after messages change and can shift the row out from under the
  # first hover on slow machines. Re-hover until the controls show.
  def hover_message(text)
    message = find("#messages > div", text: text)
    3.times do
      message.hover
      return message if message.has_css?("[data-message-target=actions]", wait: 2)
    end
    flunk "hover never revealed controls for #{text.inspect}"
  end
end
