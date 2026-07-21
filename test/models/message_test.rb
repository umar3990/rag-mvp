require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "requires content" do
    message = Message.new(conversation: conversations(:one), role: :user)
    assert_not message.valid?
    assert_includes message.errors[:content], "can't be blank"
  end

  test "requires a valid role" do
    assert_raises(ArgumentError) do
      Message.new(conversation: conversations(:one), role: :bot, content: "hi")
    end
  end

  test "tracks which documents an assistant reply drew its answer from" do
    message = messages(:two)
    message.source_documents << documents(:one)

    assert_equal [ documents(:one) ], message.reload.source_documents
  end

  test "web-sourced replies have no review status" do
    assert_nil messages(:two).review_status
  end

  test "question returns the customer message a reply answers, not any later one" do
    conversation = Conversation.create!(
      organization: organizations(:one), source: :email,
      from_email: "customer@example.com", gmail_thread_id: "18abz9y3f2e1c0d4"
    )
    first_question = conversation.messages.create!(role: :user, content: "First question", gmail_message_id: "<1@mail.gmail.com>")
    reply = conversation.messages.create!(role: :assistant, content: "First answer")
    second_question = conversation.messages.create!(role: :user, content: "Second question", gmail_message_id: "<2@mail.gmail.com>")

    assert_equal first_question, reply.question
    assert_not_equal second_question, reply.question
  end
end
