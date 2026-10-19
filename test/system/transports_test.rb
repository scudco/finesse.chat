require "application_system_test_case"
require "net/http"
require "socket"

# End-to-end delivery through each of the three transports the app exists to
# demonstrate. Messages created server-side go through the same
# after_commit broadcasts as user-posted ones (solid_cable in test, like
# production), so these prove the full server → cable DB → browser path.
class TransportsTest < ApplicationSystemTestCase
  test "websockets deliver another user's message live" do
    join_chat

    using_session :other_user do
      join_chat
      send_message "hello from the other side"
    end

    # Arrives over Action Cable without any navigation in this session.
    assert_text "hello from the other side"
  end

  test "websockets propagate edits and deletes live" do
    message = Message.create!(author: "Backstage", content: "first webs draft")
    join_chat
    assert_text "first webs draft"

    message.update!(content: "edited webs draft")
    assert_text "edited webs draft"
    assert_no_text "first webs draft"

    message.destroy!
    assert_no_text "edited webs draft"
  end

  test "polling fetches new messages on the next cycle" do
    join_chat
    click_link "Polling"
    assert_selector "[data-chat-target=pollBar]" # polling tab active

    Message.create!(author: "Backstage", content: "created mid-poll")
    # Poll interval is 7.77s; allow one full cycle plus slack.
    assert_text "created mid-poll", wait: 15
  end
end

# SSE runs in its own class with two deviations from standard system tests,
# both because Finesse is an external process reading the cable database file:
#
# 1. No transactional tests — rows written inside the never-committed test
#    transaction are invisible outside the test process.
# 2. The real solid_cable pubsub adapter — rails/test_help swaps in Action
#    Cable's in-memory Test adapter (an Async subclass, which is why WS tests
#    still pass), so broadcasts would never reach the cable database at all.
class SseTransportTest < ApplicationSystemTestCase
  self.use_transactional_tests = false

  setup do
    # Undo ActionCable::TestHelper's adapter swap; re-resolves from cable.yml.
    # Its after_teardown restores the Test adapter for subsequent tests.
    ActionCable.server.instance_variable_set(:@pubsub, nil)
  end

  teardown do
    Message.delete_all
    Presence.delete_all # the page's heartbeat commits a row too
  end

  test "sse delivers messages through the finesse server" do
    join_chat # boots the Capybara server so we know the allowed origin

    with_finesse_server do
      # Full navigation, not click_link "SSE": CSP is a document-level header,
      # and a Turbo Drive visit would keep the pre-SSE_HOST policy alive.
      visit root_url(transport: "sse")
      wait_for_sse_connection
      Message.create!(author: "Backstage", content: "hello via sse")
      assert_text "hello via sse"
    end
  end

  test "sse pushes a newcomer into the presence roster" do
    join_chat

    with_finesse_server do
      visit root_url(transport: "sse", enable_feature: "presence")
      wait_for_sse_connection
      assert_selector "#presence", text: "1 online"
      observer_heartbeat_at = Time.now

      using_session :newcomer do
        visit root_url(transport: "sse", enable_feature: "presence")
        assert_selector "#presence", text: "2 online"
      end

      assert_selector "#presence", text: "2 online"
      # The observer's own next heartbeat (30s) would also show "2 online";
      # finishing first means the broadcast did it.
      assert_operator Time.now - observer_heartbeat_at, :<, 30
    end
  end

  private

  # Boot the real Finesse Go binary against this worker's cable database and
  # point SSE_HOST (read per-request by sse_stream_url and the CSP) at it.
  def with_finesse_server
    server = Capybara.current_session.server
    origin = "http://#{server.host}:#{server.port}"
    db_path = File.expand_path(SolidCable::Record.connection_pool.db_config.database, Rails.root)
    port = free_port

    pid = Process.spawn(
      { "FINESSE_SIGNING_KEY" => Finesse.signing_key, "BINDING" => "127.0.0.1" },
      Finesse::Platforms.executable,
      "--port", port.to_s,
      "--db-path", db_path,
      "--allow-origin", origin,
      "--drain-timeout", "0s", # teardown needn't wait out the 25s production drain
      out: [ Rails.root.join("tmp/finesse_test.log").to_s, "a" ], err: [ :child, :out ]
    )
    wait_until_healthy "http://127.0.0.1:#{port}/up"

    ENV["SSE_HOST"] = "http://127.0.0.1:#{port}"
    @finesse = { pid:, port:, origin: }
    yield
  ensure
    ENV.delete("SSE_HOST")
    if pid
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end

  def free_port
    TCPServer.open("127.0.0.1", 0) { |socket| socket.addr[1] }
  end

  # Finesse replays history only on reconnect (Last-Event-ID), so a broadcast
  # sent before the EventSource finishes connecting would be lost. Wait for
  # readyState OPEN before broadcasting.
  def wait_for_sse_connection
    assert_selector "turbo-stream-source", visible: :all
    deadline = Time.now + Capybara.default_max_wait_time
    until evaluate_script("document.querySelector('turbo-stream-source')?.streamSource?.readyState") == 1
      raise "SSE connection never opened: #{sse_diagnostics} #{finesse_diagnostics}" if Time.now > deadline
      sleep 0.05
    end
  end

  # Browser-side view: src, readyState, and whether the page can reach the
  # Finesse origin at all (distinguishes CSP/CORS blocks from 4xx responses).
  def sse_diagnostics
    evaluate_async_script(<<~JS)
      const done = arguments[0];
      const el = document.querySelector("turbo-stream-source");
      const src = el?.getAttribute("src");
      const state = el?.streamSource?.readyState;
      fetch(new URL(src).origin + "/up")
        .then(r => done({ src, state, up: r.status, page: location.origin }))
        .catch(e => done({ src, state, fetchError: String(e), page: location.origin }));
    JS
  end

  # Server-side view: is the process alive and does it ACK the browser origin?
  def finesse_diagnostics
    alive = Process.kill(0, @finesse[:pid]) rescue false
    response = Net::HTTP.start("127.0.0.1", @finesse[:port]) do |http|
      req = Net::HTTP::Get.new("/up")
      req["Origin"] = "http://127.0.0.1:#{Capybara.current_session.server.port}"
      http.request(req)
    end rescue $!
    { alive:, allow_origin: @finesse[:origin], acao: response.try(:[], "Access-Control-Allow-Origin") || response.to_s }
  end

  def wait_until_healthy(url, timeout: 5)
    deadline = Time.now + timeout
    begin
      Net::HTTP.get_response(URI(url)).is_a?(Net::HTTPSuccess) || raise("unhealthy")
    rescue StandardError
      raise "Finesse server did not become healthy at #{url}" if Time.now > deadline
      sleep 0.05
      retry
    end
  end
end
