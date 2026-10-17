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

    # CI headless Chrome doesn't reliably apply CSS :hover, so click the
    # hover-revealed link directly; this test guards the delete round-trip
    # (turbo_method link, destroy, broadcast remove), not the reveal.
    message = find("#messages > div", text: "doomed message")
    execute_script("arguments[0].click()", message.find("a", text: "Delete", visible: :all))

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

  %w[ws polling sse].each do |transport|
    test "presence roster lists the connected user over #{transport}" do
      visit root_url(transport:, enable_feature: "presence") # ?transport= skips the help modal
      username = find("#current-username").text

      # The page renders "0 online"; the first heartbeat replaces it.
      assert_selector "#presence", text: "1 online"
      # Tooltip is opacity-0 until hover; CI headless Chrome hover is unreliable.
      assert_selector "#presence div", text: username, visible: :all
    end
  end

  test "presence roster stays hidden while the flag is off" do
    visit root_url(transport: "ws")
    assert_selector "#current-username"
    assert_no_selector "#presence"
  end
end
