require "test_helper"

class FeatureTest < ActiveSupport::TestCase
  test "unknown flags raise for developers" do
    assert_raises(ArgumentError) { Feature.enabled?(:never_registered) }
  end

  test "known? rejects unknown and malformed names" do
    stub_singleton Feature, :flags, { demo: false } do
      assert Feature.known?(:demo)
      assert Feature.known?("demo")
      assert_not Feature.known?("nope")
      assert_not Feature.known?([ "demo" ])
    end
  end

  test "session override beats env var beats default" do
    stub_singleton Feature, :flags, { demo: false } do
      assert_not Feature.enabled?(:demo)

      with_env "FEATURE_DEMO" => "enabled" do
        assert Feature.enabled?(:demo)
        assert_not Feature.enabled?(:demo, { features: { "demo" => false } })
      end

      with_env "FEATURE_DEMO" => "off" do
        assert_not Feature.enabled?(:demo)
      end

      assert Feature.enabled?(:demo, { features: { "demo" => true } })
    end
  end

  private

  def with_env(values)
    originals = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    originals.each { |key, value| ENV[key] = value }
  end
end
