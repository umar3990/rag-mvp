class ConversationsController < ApplicationController
  before_action :set_conversation, only: %i[ show ]
  helper_method :current_organization

  def index
    @conversations = current_organization.conversations.order(created_at: :desc)
  end

  def create
    conversation = current_organization.conversations.create!(user: Current.session.user)
    redirect_to conversation_path(conversation)
  end

  def show
    # Message.new(conversation: ...), not @conversation.messages.new --
    # the latter also appends the unsaved record to the association's
    # already-loaded in-memory array, so it would render as a phantom
    # empty bubble alongside real messages below.
    @message = Message.new(conversation: @conversation)
  end

  private
    def current_organization
      Current.session.user.organization
    end

    def set_conversation
      @conversation = current_organization.conversations.find(params[:id])
    end
end
