ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# turbo-rails includes its broadcast test helper, which swaps in the in-memory
# cable adapter, only once Action Cable's server class loads. Left lazy, the
# first test to broadcast used the real solid_cable adapter, and its writer
# thread then raced the next test's fixture transaction ("cannot start a
# transaction within a transaction").
ActionCable::Server::Base

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
