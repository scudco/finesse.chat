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

  ADJECTIVES = %w[Red Blue Green Bold Calm Cool Deft Fast Gold Jade Kind Neat Rash Sage Wild].freeze
  ANIMALS    = %w[Fox Owl Bear Wolf Lynx Crow Deer Mink Hare Pike Puma Wren Vole Newt Ibis].freeze

  def set_username
    session[:username] ||= "#{ADJECTIVES.sample}#{ANIMALS.sample}#{rand(10..99)}"
  end
end
