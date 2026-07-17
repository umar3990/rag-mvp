require "test_helper"

class GmailWebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    @valid_params = {
      message_id: "<CAF+abc123@mail.gmail.com>",
      thread_id: "18abz9y3f2e1c0d4",
      from: "customer@example.com",
      subject: "Question about my order",
      body_text: "I'd like to return an item I bought last week."
    }
  end

  test "401s for a token that doesn't match any organization" do
    post gmail_webhook_path("not-a-real-token"), params: @valid_params
    assert_response :unauthorized
  end

  test "422s when a required field is missing" do
    post gmail_webhook_path(@organization.webhook_token), params: @valid_params.except(:body_text)
    assert_response :unprocessable_entity
    assert_match "body_text", response.parsed_body["error"]
  end

  test "creates a conversation and inbound message, and enqueues processing" do
    assert_enqueued_with(job: InboundEmailProcessingJob) do
      assert_difference [ "Conversation.count", "Message.count" ], 1 do
        post gmail_webhook_path(@organization.webhook_token), params: @valid_params
      end
    end

    assert_response :success

    conversation = @organization.conversations.find_by!(gmail_thread_id: @valid_params[:thread_id])
    assert conversation.email?
    assert_equal "customer@example.com", conversation.from_email

    message = conversation.messages.sole
    assert message.user?
    assert_equal @valid_params[:body_text], message.content
    assert_equal @valid_params[:message_id], message.gmail_message_id
  end

  test "a second email in the same thread reuses the conversation" do
    post gmail_webhook_path(@organization.webhook_token), params: @valid_params

    assert_difference "Conversation.count", 0 do
      assert_difference "Message.count", 1 do
        post gmail_webhook_path(@organization.webhook_token), params: @valid_params.merge(
          message_id: "<CAF+def456@mail.gmail.com>", body_text: "Following up on my last email."
        )
      end
    end
  end

  test "redelivering the same message_id is a no-op, not a duplicate" do
    post gmail_webhook_path(@organization.webhook_token), params: @valid_params

    assert_no_difference [ "Conversation.count", "Message.count" ] do
      post gmail_webhook_path(@organization.webhook_token), params: @valid_params
    end

    assert_response :success
  end

  test "never lets one organization's token create data under another organization" do
    post gmail_webhook_path(organizations(:two).webhook_token), params: @valid_params

    conversation = organizations(:two).conversations.find_by!(gmail_thread_id: @valid_params[:thread_id])
    assert_not organizations(:one).conversations.exists?(gmail_thread_id: @valid_params[:thread_id])
    assert_equal organizations(:two), conversation.organization
  end
end
