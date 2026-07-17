require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "orders messages oldest first" do
    conversation = conversations(:one)
    assert_equal [ messages(:one), messages(:two) ], conversation.messages.to_a
  end

  test "destroying a conversation destroys its messages" do
    conversation = conversations(:one)
    assert_difference -> { Message.count }, -2 do
      conversation.destroy
    end
  end

  test "web-sourced conversations don't need an email or Gmail thread id" do
    conversation = Conversation.new(organization: organizations(:one), user: users(:one), source: :web)
    assert conversation.valid?
  end

  test "email-sourced conversations require a from address and a Gmail thread id" do
    conversation = Conversation.new(organization: organizations(:one), source: :email)
    assert_not conversation.valid?
    assert_includes conversation.errors[:from_email], "can't be blank"
    assert_includes conversation.errors[:gmail_thread_id], "can't be blank"
  end

  test "email-sourced conversations don't need an app user" do
    conversation = Conversation.new(
      organization: organizations(:one), source: :email,
      from_email: "customer@example.com", gmail_thread_id: "18abz9y3f2e1c0d4"
    )
    assert conversation.valid?
  end

  test "the same Gmail thread id is fine across different organizations" do
    Conversation.create!(
      organization: organizations(:one), source: :email,
      from_email: "customer@example.com", gmail_thread_id: "shared-thread-id"
    )

    conversation = Conversation.new(
      organization: organizations(:two), source: :email,
      from_email: "someone-else@example.com", gmail_thread_id: "shared-thread-id"
    )
    assert conversation.valid?
  end
end
