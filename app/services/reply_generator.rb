# Shared by both callers of AnswerGenerator -- the chat UI
# (MessagesController) and the inbound-email pipeline
# (InboundEmailProcessingJob). Same "AI Agent step" either way, per
# CLAUDE.md's Phase 5 plan: just a different trigger, not different logic.
class ReplyGenerator
  # No answer in the knowledge base is trustworthy enough to send --
  # AnswerGenerator already decided that before this ever gets called.
  # Phrased without promising a human follow-up: escalated or not, an
  # email-sourced reply always needs human review before sending (below),
  # so this only tells the reviewer honestly that nothing confident was
  # found -- it never reaches the customer unedited.
  NO_CONFIDENT_ANSWER = "I don't have enough information in the knowledge base to answer that confidently."

  def self.call(conversation:, question:)
    result = AnswerGenerator.call(question: question, organization: conversation.organization)

    # Every email-sourced reply needs a human to approve it before
    # sending -- confident or not. Web-sourced chat replies show
    # directly to the user asking, so review_status stays nil there.
    review_status = conversation.email? ? :pending : nil

    if result.escalated?
      conversation.messages.create!(role: :assistant, escalated: true, review_status: review_status, content: NO_CONFIDENT_ANSWER)
    else
      reply = conversation.messages.create!(role: :assistant, escalated: false, review_status: review_status, content: result.answer)
      result.sources.each { |document| reply.message_sources.create!(document: document) }
      reply
    end
  end
end
