require "test_helper"

class SendApprovedReplyJobTest < ActiveJob::TestCase
  setup do
    @organization = organizations(:one)
    @organization.update!(
      n8n_send_webhook_url: "https://n8n.example.com/webhook/acme-send",
      n8n_send_webhook_secret: "shh-its-a-secret"
    )
    @conversation = Conversation.create!(
      organization: @organization, source: :email,
      from_email: "customer@example.com", gmail_thread_id: "18abz9y3f2e1c0d4"
    )
    @conversation.messages.create!(role: :user, content: "What's your return policy?", gmail_message_id: "<q@mail.gmail.com>")
    @reply = @conversation.messages.create!(role: :assistant, content: "Returns are accepted within 30 days.", review_status: :approved)
  end

  test "calls OutboundEmailService and records when it was sent" do
    stub_request(:post, "https://n8n.example.com/webhook/acme-send").to_return(status: 200, body: "{}")

    SendApprovedReplyJob.perform_now(@reply)

    assert_not_nil @reply.reload.sent_at
  end

  test "does nothing if the message was already sent -- guards a retried job against sending twice" do
    @reply.update!(sent_at: 1.hour.ago)

    stub = stub_request(:post, "https://n8n.example.com/webhook/acme-send")

    SendApprovedReplyJob.perform_now(@reply)

    assert_not_requested stub
  end

  test "does nothing for a web-sourced message -- review/send only applies to email" do
    web_reply = messages(:two)
    stub = stub_request(:post, "https://n8n.example.com/webhook/acme-send")

    SendApprovedReplyJob.perform_now(web_reply)

    assert_not_requested stub
    assert_nil web_reply.reload.sent_at
  end
end
