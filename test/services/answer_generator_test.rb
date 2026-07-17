require "test_helper"

class AnswerGeneratorTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @document = documents(:one)
  end

  test "escalates instead of answering when nothing relevant is in the knowledge base" do
    stub_embedding(unit_vector(0)) do
      result = AnswerGenerator.call(question: "irrelevant, stubbed below", organization: @organization)
      assert result.escalated?
      assert_nil result.answer
      assert_empty result.sources
    end
  end

  test "escalates when the closest match is too dissimilar to trust" do
    create_chunk(100, unit_vector(0).map { |v| -v }) # opposite direction: max cosine distance

    stub_embedding(unit_vector(0)) do
      result = AnswerGenerator.call(question: "irrelevant, stubbed below", organization: @organization)
      assert result.escalated?
    end
  end

  test "answers using retrieved chunks as context when a good match exists" do
    chunk = create_chunk(100, unit_vector(0))

    stub_embedding(unit_vector(0)) do
      stub_chat("Returns are accepted within 30 days.") do
        result = AnswerGenerator.call(question: "What's the return policy?", organization: @organization)

        assert_not result.escalated?
        assert_equal "Returns are accepted within 30 days.", result.answer
        assert_equal [ chunk.document ], result.sources
      end
    end
  end

  private

  def unit_vector(index)
    Array.new(768, 0.0).tap { |v| v[index] = 1.0 }
  end

  def create_chunk(position, embedding)
    Chunk.create!(document: @document, organization: @organization, content: "content", position: position, embedding: embedding)
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
