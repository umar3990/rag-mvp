# Enqueued by MessageReviewsController#approve. Actual delivery goes
# through n8n (OutboundEmailService), not Gmail directly -- see
# docs/webhook-contract.md.
class SendApprovedReplyJob < ApplicationJob
  queue_as :default

  retry_on OutboundEmailService::RequestFailed, wait: :polynomially_longer, attempts: 5

  def perform(message)
    # Guards against sending twice if this job is retried after a
    # request that actually succeeded but failed to report back in
    # time (e.g. a slow response the retry logic gave up waiting on).
    return if message.sent_at.present?
    return unless message.conversation.email?

    OutboundEmailService.call(message)
    message.update!(sent_at: Time.current)
  end
end
