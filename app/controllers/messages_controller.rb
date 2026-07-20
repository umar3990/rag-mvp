class MessagesController < ApplicationController
  before_action :set_conversation
  helper_method :current_organization

  def create
    @message = @conversation.messages.new(message_params.merge(role: :user))

    if @message.save
      @reply = ReplyGenerator.call(conversation: @conversation, question: @message.content)
      @blank_message = Message.new(conversation: @conversation)
    else
      return render turbo_stream: turbo_stream.replace(
        "new_message_form", partial: "messages/form", locals: { conversation: @conversation, message: @message }
      ), status: :unprocessable_entity
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to conversation_path(@conversation) }
    end
  end

  private
    def current_organization
      Current.session.user.organization
    end

    def set_conversation
      @conversation = current_organization.conversations.find(params[:conversation_id])
    end

    def message_params
      params.require(:message).permit(:content)
    end
end
