# The seam between n8n and Rails -- see docs/webhook-contract.md for the
# payload shape, auth, and response codes this implements. Deliberately
# thin: verify + dedupe + hand off to a background job, nothing slower
# than that runs inline, so n8n never times out waiting on us.
class GmailWebhooksController < ApplicationController
  allow_unauthenticated_access
  # No session cookie exists on a machine-to-machine request, so there's
  # no CSRF token to check -- :webhook_token in the URL is the real
  # authentication here, not the session Rails' forgery protection
  # assumes exists.
  skip_forgery_protection

  REQUIRED_FIELDS = %i[ message_id thread_id from body_text ].freeze

  def create
    organization = Organization.find_by(webhook_token: params[:webhook_token])
    return head :unauthorized unless organization

    payload = params.permit(*REQUIRED_FIELDS, :subject)
    missing = REQUIRED_FIELDS.select { |field| payload[field].blank? }
    return render json: { error: "missing required fields: #{missing.join(', ')}" }, status: :unprocessable_entity if missing.any?

    # create_or_find_by -- not find_or_create_by -- because two webhook
    # deliveries for the first email in a brand-new thread could race
    # each other here; create_or_find_by rescues the unique-index
    # violation and falls back to a find instead of raising.
    conversation = organization.conversations.create_or_find_by!(source: :email, gmail_thread_id: payload[:thread_id]) do |c|
      c.from_email = payload[:from]
    end

    message = conversation.messages.create!(role: :user, content: payload[:body_text], gmail_message_id: payload[:message_id])

    InboundEmailProcessingJob.perform_later(message)

    render json: { status: "ok" }, status: :ok
  rescue ActiveRecord::RecordNotUnique
    # The true race: two deliveries for the same message_id reached the
    # uniqueness validation at nearly the same instant, both passed it,
    # and the DB's unique index (not the validation) is what actually
    # stopped the second insert. Same outcome as the validation catching
    # it below -- tell n8n this is already handled, not an error to retry.
    render json: { status: "ok", note: "already processed" }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    if e.record.errors[:gmail_message_id].any?
      render json: { status: "ok", note: "already processed" }, status: :ok
    else
      render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
