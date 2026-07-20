require "test_helper"

class InboundEmailProcessingJobTest < ActiveJob::TestCase
  test "generates and persists a reply on the message's conversation" do
    conversation = Conversation.create!(
      organization: organizations(:one), source: :email,
      from_email: "customer@example.com", gmail_thread_id: "18abz9y3f2e1c0d4"
    )
    message = conversation.messages.create!(role: :user, content: "What's the weather like on Mars?", gmail_message_id: "<abc@mail.gmail.com>")

    stub_embedding(unit_vector(0)) do
      assert_difference -> { conversation.messages.reload.count }, 1 do
        InboundEmailProcessingJob.perform_now(message)
      end
    end

    reply = conversation.messages.assistant.order(:created_at).last
    assert reply.escalated?
  end

  private

  def unit_vector(index)
    Array.new(768, 0.0).tap { |v| v[index] = 1.0 }
  end

  def stub_embedding(vector)
    original_method = EmbeddingService.method(:call)
    EmbeddingService.define_singleton_method(:call) { |*| vector }
    yield
  ensure
    EmbeddingService.define_singleton_method(:call, original_method)
  end
end
