class MessagesController < ApplicationController
  before_action :set_conversation
  helper_method :current_organization

  # No answer in the knowledge base is trustworthy enough to send --
  # AnswerGenerator already decided that before this ever gets called.
  # Phrased without promising a human follow-up: that hand-off (Phase 5)
  # doesn't exist yet, so this only tells the user honestly that nothing
  # confident was found.
  NO_CONFIDENT_ANSWER = "I don't have enough information in the knowledge base to answer that confidently."

  def create
    @message = @conversation.messages.new(message_params.merge(role: :user))

    if @message.save
      @reply = generate_reply_to(@message)
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

    def generate_reply_to(message)
      result = AnswerGenerator.call(question: message.content, organization: current_organization)

      if result.escalated?
        @conversation.messages.create!(role: :assistant, escalated: true, content: NO_CONFIDENT_ANSWER)
      else
        reply = @conversation.messages.create!(role: :assistant, escalated: false, content: result.answer)
        result.sources.each { |document| reply.message_sources.create!(document: document) }
        reply
      end
    end
end
