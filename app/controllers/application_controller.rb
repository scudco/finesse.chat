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

  # Derive a username deterministically from the session ID so that the same
  # session always produces the same name and collisions are as unlikely as
  # two sessions sharing a cryptographic ID.
  # 1,633 words × 1,633 words = ~2.6M combinations; 50% collision at ~2,300 users.
  def set_username
    session[:username] ||= begin
      hash   = Digest::SHA256.hexdigest(request.session.id.to_s).to_i(16)
      [
        WORDS[hash % WORDS.length].capitalize,
        WORDS[(hash / WORDS.length) % WORDS.length].capitalize
      ].join
    end
  end
end
