require "test_helper"

class OutboundEmailServiceTest < ActiveSupport::TestCase
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
    @question = @conversation.messages.create!(role: :user, content: "What's your return policy?", gmail_message_id: "<q@mail.gmail.com>")
    @reply = @conversation.messages.create!(role: :assistant, content: "Returns are accepted within 30 days.", review_status: :approved)
  end

  test "posts the reply to the organization's n8n send webhook with the expected payload and auth header" do
    stub = stub_request(:post, "https://n8n.example.com/webhook/acme-send")
      .with(
        headers: { "X-Webhook-Token" => "shh-its-a-secret", "Content-Type" => "application/json" },
        body: {
          to: "customer@example.com",
          body: "Returns are accepted within 30 days.",
          gmail_thread_id: "18abz9y3f2e1c0d4",
          in_reply_to: "<q@mail.gmail.com>"
        }.to_json
      )
      .to_return(status: 200, body: "{}")

    OutboundEmailService.call(@reply)

    assert_requested stub
  end

  test "raises when n8n's webhook doesn't respond successfully" do
    stub_request(:post, "https://n8n.example.com/webhook/acme-send").to_return(status: 500, body: "boom")

    assert_raises(OutboundEmailService::RequestFailed) do
      OutboundEmailService.call(@reply)
    end
  end
end
