# Minimal feature flags for dark-launching work on main.
#
# Precedence: per-session override > FEATURE_<NAME> env var > default below.
#
# Workflow: register a flag default-off, ship to main, verify live with
# ?enable_feature=<name> (sets a session override for you alone), then set
# FEATURE_<NAME>=enabled in config/deploy.yml for everyone. Delete the flag
# once the feature is proven.
#
# ponytail: in-memory registry, no admin UI. Reach for Flipper if flags ever
# need percentage rollouts or runtime toggling without a deploy.
module Feature
  FLAGS = {
    presence: false # "N online" roster in the chat header
  }.freeze

  ENABLED_VALUES = %w[1 true on enabled].freeze

  class << self
    def enabled?(name, session = nil)
      name = name.to_sym
      raise ArgumentError, "Unknown feature flag: #{name}" unless known?(name)

      override = session && session[:features]&.dig(name.to_s)
      return override unless override.nil?

      env = ENV["FEATURE_#{name.to_s.upcase}"]
      return ENABLED_VALUES.include?(env) unless env.nil?

      flags[name]
    end

    def known?(name) = name.respond_to?(:to_sym) && flags.key?(name.to_sym)

    # Indirection so tests can stub the registry.
    def flags = FLAGS
  end
end
