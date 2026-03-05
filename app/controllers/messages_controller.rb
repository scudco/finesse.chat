class MessagesController < ApplicationController
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_csrf_error

  before_action :set_message, only: %i[ update destroy ]

  # GET /messages or /messages.json
  def index
    session[:transport] = params[:transport] if params[:transport].in?(%w[ws sse none])
    @transport = session[:transport] || "ws"
    @messages = Message.order(:id).last(50)
  end

  # POST /messages/bot_storm
  def bot_storm
    return head :too_many_requests if BotStormJob.running?

    BotStormJob.perform_later(count: 250)
    head :no_content
  end

  # GET /messages/older?before_id=N  (turbo stream)
  def older
    messages = Message.where(id: ...params[:before_id].to_i).order(id: :desc).limit(50)
    render turbo_stream: messages.map { |message| turbo_stream.prepend("messages", partial: "message", locals: { message: }) }
  end

  # GET /messages/newer  (turbo stream, polling fallback — replaces full list)
  def newer
    messages = Message.order(:id).last(50)
    digest = "#{messages.last&.id}-#{messages.maximum(:updated_at)&.to_i}"
    if params[:digest] == digest
      head :no_content and return
    end
    response.set_header("X-Messages-Digest", digest)
    render turbo_stream: turbo_stream.update("messages", partial: "messages_list", locals: { messages: })
  end

  # POST /messages
  def create
    content = message_params[:content].to_s

    if SlashCommand.match?(content)
      cmd = SlashCommand.new(content, author: current_username)
      @bot_message = FinesseBot.call(cmd.bot_input, invoked_by: current_username) if cmd.bot_input
      @message = cmd.message
    else
      @message = Message.new(message_params.merge(author: current_username))
    end

    if @message && !@message.save
      render turbo_stream: turbo_stream.update("message_form", partial: "form", locals: { message: @message })
      return
    end

    streams = [ turbo_stream.update("message_form", partial: "form", locals: { message: Message.new }) ]
    streams.unshift turbo_stream.append("messages", partial: "message", locals: { message: @bot_message }) if @bot_message
    streams.unshift turbo_stream.append("messages", partial: "message", locals: { message: @message }) if @message
    render turbo_stream: streams
  end

  # PATCH/PUT /messages/1
  def update
    if @message.update(message_params)
      render turbo_stream: turbo_stream.replace(@message, partial: "message", locals: { message: @message, current_user: current_username })
    else
      render turbo_stream: turbo_stream.replace(@message, partial: "message", locals: { message: @message, current_user: current_username, editing: true })
    end
  end

  # DELETE /messages/1
  def destroy
    @message.destroy!
    render turbo_stream: turbo_stream.remove(@message)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_message
      @message = Message.where(author: current_username).find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def message_params = params.expect(message: %i[ content ])

    def handle_csrf_error
      respond_to do |format|
        format.turbo_stream do
          set_username # before_action may not have run yet
          message = Message.new(content: params.dig(:message, :content))
          message.errors.add(:base, "Session expired — your message is preserved, please resend.")
          render turbo_stream: turbo_stream.update("message_form",
            partial: "form", locals: { message: })
        end
        format.html { redirect_to root_path }
      end
    end
end
