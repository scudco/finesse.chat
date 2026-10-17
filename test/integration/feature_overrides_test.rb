require "test_helper"

class FeatureOverridesTest < ActionDispatch::IntegrationTest
  test "enable and disable params set session overrides" do
    stub_singleton Feature, :flags, Feature.flags.merge(demo: false) do # the page checks real flags too
      get root_url, params: { enable_feature: "demo" }
      assert_response :success
      assert_equal({ "demo" => true }, session[:features])

      get root_url, params: { disable_feature: "demo" }
      assert_response :success
      assert_equal({ "demo" => false }, session[:features])
    end
  end

  test "unknown or malformed feature params are ignored" do
    get root_url, params: { enable_feature: "never_registered" }
    assert_response :success
    assert_nil session[:features]

    get root_url, params: { enable_feature: [ "demo" ] }
    assert_response :success
    assert_nil session[:features]
  end
end
