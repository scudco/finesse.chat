class SessionsController < ApplicationController
  def update
    session[:username] = ApplicationController::WORDS.sample(2).map(&:capitalize).join
    color = helpers.author_color(current_username)
    render turbo_stream: turbo_stream.replace("current-username",
      helpers.tag.strong(current_username, id: "current-username", style: "color: #{color}"))
  end
end
