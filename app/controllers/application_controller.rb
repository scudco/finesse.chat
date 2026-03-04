class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_username
  helper_method :current_username

  def current_username
    session[:username]
  end

  private

  WORDS = File.readlines(Rails.root.join("db/wordlist.txt"), chomp: true).freeze

  # Pick two distinct random words on first visit and persist in session.
  # 1,633 × 1,632 = ~2.7M combinations; 50% collision at ~2,300 users.
  def set_username
    session[:username] ||= WORDS.sample(2).map(&:capitalize).join
  end
end
