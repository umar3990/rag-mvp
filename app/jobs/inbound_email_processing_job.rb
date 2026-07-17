# Stub -- the webhook's job is verify + dedupe + hand off fast; this is
# where that hand-off lands. Next increment: call AnswerGenerator against
# the message's content, persist the draft reply as an assistant Message
# (same shape MessagesController already uses), and leave it for a human
# to approve (Phase 5's approval UI, not built yet).
class InboundEmailProcessingJob < ApplicationJob
  queue_as :default

  def perform(message)
  end
end
