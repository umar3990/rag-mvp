require "test_helper"

class ChunkRetrieverTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    @document = documents(:one)
    @other_document = documents(:two)
  end

  test "returns chunks ordered by cosine similarity, closest first" do
    same_direction = unit_vector(0)
    orthogonal = unit_vector(1)
    opposite_direction = unit_vector(0).map { |v| -v }

    far = create_chunk(@document, @organization, 100, opposite_direction)
    near = create_chunk(@document, @organization, 101, same_direction)
    middle = create_chunk(@document, @organization, 102, orthogonal)

    stub_embedding(same_direction) do
      results = ChunkRetriever.call(question: "irrelevant, stubbed below", organization: @organization)
      assert_equal [ near, middle, far ], results
    end
  end

  test "never returns chunks from another organization" do
    query_vector = unit_vector(0)
    matching_in_other_org = create_chunk(@other_document, @other_organization, 100, query_vector)
    create_chunk(@document, @organization, 100, unit_vector(1))

    stub_embedding(query_vector) do
      results = ChunkRetriever.call(question: "irrelevant, stubbed below", organization: @organization)
      assert_not_includes results, matching_in_other_org
    end
  end

  test "respects the limit" do
    3.times { |i| create_chunk(@document, @organization, 100 + i, unit_vector(i % 2)) }

    stub_embedding(unit_vector(0)) do
      results = ChunkRetriever.call(question: "irrelevant, stubbed below", organization: @organization, limit: 2)
      assert_equal 2, results.size
    end
  end

  private

  # A 768-dim vector that's 1 in a single position and 0 elsewhere --
  # two different indexes give vectors at a known 90-degree angle
  # (orthogonal), useful for asserting exact similarity ordering.
  def unit_vector(index)
    Array.new(768, 0.0).tap { |v| v[index] = 1.0 }
  end

  def create_chunk(document, organization, position, embedding)
    Chunk.create!(document: document, organization: organization, content: "content", position: position, embedding: embedding)
  end

  def stub_embedding(vector)
    original_method = EmbeddingService.method(:call)
    EmbeddingService.define_singleton_method(:call) { |*| vector }
    yield
  ensure
    EmbeddingService.define_singleton_method(:call, original_method)
  end
end
