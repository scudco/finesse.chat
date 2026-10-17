require "test_helper"

class PresencesControllerTest < ActionDispatch::IntegrationTest
  setup { get root_url, params: { enable_feature: "presence" } }

  test "heartbeat records the user and renders the roster in username order" do
    Presence.create!(username: "Zed", last_seen_at: 10.seconds.ago)
    Presence.create!(username: "Gone", last_seen_at: (Presence::WINDOW + 1.second).ago)

    post presence_url, as: :turbo_stream
    assert_response :success
    me = session[:username]

    assert_select "turbo-stream[action=replace][target=presence]"
    expected = [ me, "Zed" ].sort
    assert_equal expected, css_select("#presence div div").map { |el| el.text.strip }
    assert_match "2 online", response.body
  end

  test "repeat heartbeats refresh one row per user" do
    post presence_url, as: :turbo_stream
    first_seen = Presence.find_by!(username: session[:username]).last_seen_at

    travel 30.seconds do
      post presence_url, as: :turbo_stream
    end

    assert_equal 1, Presence.where(username: session[:username]).count
    assert_operator Presence.find_by!(username: session[:username]).last_seen_at, :>, first_seen
  end

  test "count stays exact while the tooltip caps at 50 names" do
    Presence.insert_all(Array.new(60) { |i| { username: "Bot#{i}", last_seen_at: Time.current } })

    post presence_url, as: :turbo_stream

    assert_match "61 online", response.body
    assert_equal 50, css_select("#presence div div:not(.text-gray-400)").size
    assert_match "and 11 more", response.body
  end

  test "heartbeat is a 404 that records nothing while the flag is off" do
    get root_url, params: { disable_feature: "presence" }

    post presence_url, as: :turbo_stream

    assert_response :not_found
    assert_equal 0, Presence.count
  end
end
