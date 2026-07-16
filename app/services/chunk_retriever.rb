# Given a question, finds the most semantically similar chunks within a
# single organization -- the retrieval half of RAG. Generation (building a
# prompt from these chunks, calling a chat model, confidence/escalate
# check) is a separate step built later; this only answers "which chunks
# are relevant."
class ChunkRetriever
  DEFAULT_LIMIT = 5

  def self.call(question:, organization:, limit: DEFAULT_LIMIT)
    query_embedding = EmbeddingService.call(question)

    # neighbor's nearest_neighbors adds `ORDER BY <embedding> <=> query`
    # (pgvector's cosine distance operator) plus a selected
    # `neighbor_distance` column -- closest first, 0 = identical direction,
    # 2 = opposite direction. Scoping to `organization` first keeps this a
    # plain SQL AND, so a perfect match in another org can never leak in.
    Chunk
      .where(organization: organization)
      .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .first(limit)
  end
end
