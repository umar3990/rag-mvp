# Shared by both callers of AnswerGenerator -- the chat UI
# (MessagesController) and the inbound-email pipeline
# (InboundEmailProcessingJob). Same "AI Agent step" either way, per
# CLAUDE.md's Phase 5 plan: just a different trigger, not different logic.
class ReplyGenerator
  # No answer in the knowledge base is trustworthy enough to send --
  # AnswerGenerator already decided that before this ever gets called.
  # Phrased without promising a human follow-up: that hand-off (Phase 5's
  # approval UI) doesn't exist yet, so this only tells the user honestly
  # that nothing confident was found.
  NO_CONFIDENT_ANSWER = "I don't have enough information in the knowledge base to answer that confidently."

  def self.call(conversation:, question:)
    result = AnswerGenerator.call(question: question, organization: conversation.organization)

    if result.escalated?
      conversation.messages.create!(role: :assistant, escalated: true, content: NO_CONFIDENT_ANSWER)
    else
      reply = conversation.messages.create!(role: :assistant, escalated: false, content: result.answer)
      result.sources.each { |document| reply.message_sources.create!(document: document) }
      reply
    end
  end
end
