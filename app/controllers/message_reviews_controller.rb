# The human-in-the-loop step: every email-sourced assistant reply sits
# here as review_status_pending -- confident or escalated, it doesn't
# matter, nothing reaches a real customer without a person approving it
# first. "Edit & Approve" isn't a separate action from "Approve": the
# form always submits whatever's in the content field, edited or not.
class MessageReviewsController < ApplicationController
  before_action :set_message, only: %i[ approve reject ]
  helper_method :current_organization

  def index
    @messages = pending_messages
  end

  def approve
    @message.update!(
      content: params.require(:content),
      review_status: :approved, reviewed_by: Current.session.user, reviewed_at: Time.current
    )
    redirect_to reviews_path, notice: "Approved."
  end

  def reject
    @message.update!(review_status: :rejected, reviewed_by: Current.session.user, reviewed_at: Time.current)
    redirect_to reviews_path, notice: "Rejected."
  end

  private
    def current_organization
      Current.session.user.organization
    end

    def pending_messages
      Message.joins(:conversation)
        .where(conversation: { organization_id: current_organization.id, source: :email })
        .where(role: :assistant, review_status: :pending)
        .order(:created_at)
    end

    # Scoping the lookup through pending_messages (not Message.find)
    # means a message belonging to another organization, or one that's
    # already been reviewed, 404s instead of silently double-processing.
    def set_message
      @message = pending_messages.find(params[:id])
    end
end
