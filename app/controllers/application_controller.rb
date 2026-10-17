class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_username
  before_action :apply_feature_overrides
  helper_method :current_username

  def current_username = session[:username]

  private

  WORDS = File.readlines(Rails.root.join("db/wordlist.txt"), chomp: true).freeze

  # Pick two distinct random words on first visit and persist in session.
  # 1,633 × 1,632 = ~2.7M combinations; 50% collision at ~2,300 users.
  def set_username
    session[:username] ||= WORDS.sample(2).map(&:capitalize).join
  end

  # Session-scoped feature flag overrides: ?enable_feature=name / ?disable_feature=name.
  # Unknown names are ignored — URL params must never 500 the app.
  def apply_feature_overrides
    { enable_feature: true, disable_feature: false }.each do |param, value|
      name = params[param]
      next unless name.is_a?(String) && Feature.known?(name)
      (session[:features] ||= {})[name] = value
    end
  end
end
