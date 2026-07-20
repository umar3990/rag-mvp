# Generates a draft reply to an inbound email -- same ReplyGenerator step
# the chat UI uses, just triggered by GmailWebhooksController instead of
# MessagesController. The reply is persisted, not sent: there's no
# approval UI yet (Phase 5's next increment), so a draft sitting on the
# conversation is as far as this goes for now.
class InboundEmailProcessingJob < ApplicationJob
  queue_as :default

  def perform(message)
    ReplyGenerator.call(conversation: message.conversation, question: message.content)
  end
end
