# Capybara 3.40.0 ends ChromeDriver#reset! with the CDP call
# Storage.clearDataForOrigin(origin: "*") to clear cookies and local storage for
# every origin. Chrome 158 rejects "*" ("invalid argument: * is not a valid URL"),
# so every system test errored in teardown.
# Upstream: https://github.com/teamcapybara/capybara/issues/2865 (fixes proposed in
# #2867 and #2868, unreleased as of 3.40.0).
#
# This keeps reset!'s behavior: it still sends "*" first (Chrome 157 and older
# accept it), and when Chrome rejects it, clears all cookies with
# Network.clearBrowserCookies and the remaining storage types for each origin
# the tab visited plus the app server's origin.
#
# Delete this file and its require in application_system_test_case.rb once a
# Capybara release fixes #2865. The version guard turns the patch off on any
# newer Capybara, so a release without the fix fails loudly again.
module CapybaraChrome158Reset
  private

  def execute_cdp(cmd, params = {})
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError
    raise unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    types = params[:storageTypes].split(",")
    super("Network.clearBrowserCookies") if types.delete("cookies")
    return if types.empty?

    storage_origins.each do |origin|
      super(cmd, origin: origin, storageTypes: types.join(","))
    end
  end

  def storage_origins
    visited = execute_cdp("Page.getNavigationHistory")["entries"].map { |entry| entry["url"] }
    app_server = Capybara.current_session.server&.base_url

    [ *visited, app_server ].filter_map do |url|
      uri = URI.parse(url.to_s)
      uri.origin if uri.is_a?(URI::HTTP) && uri.host
    rescue URI::InvalidURIError
      nil
    end.uniq
  end
end

if Capybara::VERSION == "3.40.0"
  Capybara::Selenium::Driver::ChromeDriver.prepend(CapybaraChrome158Reset)
end
