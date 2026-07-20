require "test_helper"

class ReplyGeneratorTest < ActiveSupport::TestCase
  setup do
    @conversation = conversations(:one)
  end

  test "persists an escalation message when nothing relevant is in the knowledge base" do
    stub_embedding(unit_vector(0)) do
      reply = ReplyGenerator.call(conversation: @conversation, question: "What's the weather like on Mars?")

      assert reply.persisted?
      assert reply.assistant?
      assert reply.escalated?
      assert_equal ReplyGenerator::NO_CONFIDENT_ANSWER, reply.content
    end
  end

  test "persists a grounded reply with sources when a good match exists" do
    chunk = Chunk.create!(
      document: documents(:one), organization: @conversation.organization,
      content: "Returns are accepted within 30 days of purchase with a receipt.", position: 100,
      embedding: unit_vector(0)
    )

    stub_embedding(unit_vector(0)) do
      stub_chat("Returns are accepted within 30 days.") do
        reply = ReplyGenerator.call(conversation: @conversation, question: "What's the return policy?")

        assert_not reply.escalated?
        assert_equal "Returns are accepted within 30 days.", reply.content
        assert_equal [ chunk.document ], reply.source_documents
      end
    end
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

  def stub_chat(answer)
    original_method = ChatCompletionService.method(:call)
    ChatCompletionService.define_singleton_method(:call) { |*| answer }
    yield
  ensure
    ChatCompletionService.define_singleton_method(:call, original_method)
  end
end
