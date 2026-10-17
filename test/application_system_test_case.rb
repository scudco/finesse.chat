require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Cable delivery (solid_cable polls every 0.1s) needs a little more patience
  # than Capybara's 2s default.
  Capybara.default_max_wait_time = 5

  private

  # Visit the chat and dismiss the startup help modal.
  def join_chat(**params)
    visit root_url(**params)
    click_button "Start chatting"
  end

  def send_message(content)
    fill_in "message[content]", with: content
    click_button "Send"
    assert_text content
  end
end
