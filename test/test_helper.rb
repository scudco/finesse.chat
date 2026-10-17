ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Minitest 6 dropped minitest/mock; this is the slice of stubbing we need.
    # Replaces a singleton method (e.g. Feature.flags) for the block's duration.
    def stub_singleton(owner, name, value)
      singleton = owner.singleton_class
      original = singleton.instance_method(name)
      singleton.define_method(name) { |*| value }
      yield
    ensure
      singleton.define_method(name, original)
    end
  end
end
