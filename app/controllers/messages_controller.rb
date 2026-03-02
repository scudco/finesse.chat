class MessagesController < ApplicationController
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_csrf_error

  before_action :set_message, only: %i[ show edit update destroy ]

  # GET /messages or /messages.json
  def index
    session[:transport] = params[:transport] if params[:transport].in?(%w[ws sse none])
    @transport = session[:transport] || "ws"
    @messages = Message.order(:id).last(50)
  end

  # GET /messages/older?before_id=N  (turbo stream)
  def older
    @messages = Message.where(id: ...params[:before_id].to_i).order(id: :desc).limit(50)
    render turbo_stream: @messages.map { |m|
      turbo_stream.prepend("messages", partial: "message", locals: { message: m })
    }
  end

  # GET /messages/newer?after_id=N  (turbo stream, polling fallback)
  def newer
    @messages = Message.where(id: params[:after_id].to_i..).order(id: :asc).limit(50)
    render turbo_stream: @messages.map { |m|
      turbo_stream.append("messages", partial: "message", locals: { message: m })
    }
  end

  # GET /messages/1 or /messages/1.json
  def show
  end

  # GET /messages/new
  def new
    @message = Message.new
  end

  # GET /messages/1/edit
  def edit
  end

  # POST /messages or /messages.json
  def create
    @message = Message.new(message_params)
    @message.author = current_username

    respond_to do |format|
      if @message.save
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("messages", partial: "message", locals: { message: @message }),
            turbo_stream.update("message_form", partial: "form", locals: { message: Message.new })
          ]
        end
        format.html { redirect_to messages_path }
        format.json { render :show, status: :created, location: @message }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.update("message_form", partial: "form", locals: { message: @message }) }
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @message.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /messages/1 or /messages/1.json
  def update
    respond_to do |format|
      if @message.update(message_params)
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@message, partial: "message", locals: { message: @message, current_user: current_username }) }
        format.html { redirect_to messages_path }
        format.json { render :show, status: :ok, location: @message }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@message, partial: "message", locals: { message: @message, current_user: current_username }) }
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @message.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /messages/1 or /messages/1.json
  def destroy
    @message.destroy!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@message) }
      format.html { redirect_to messages_path }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_message
      @message = Message.where(author: current_username).find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def message_params
      params.expect(message: %i[ content ])
    end

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
