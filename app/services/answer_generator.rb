# Ties retrieval and generation together: embeds the question (via
# ChunkRetriever -> EmbeddingService), checks whether the closest match is
# even relevant, and only then asks the chat model to answer -- skipping
# straight to escalation when nothing relevant was found instead of
# letting the model guess.
class AnswerGenerator
  Result = Struct.new(:answer, :sources, :escalated?, keyword_init: true)

  # Cosine distance ranges 0 (identical direction) to 2 (opposite).
  # Anything above this is treated as "nothing relevant in the knowledge
  # base" -- a judgment call to tune against real questions, not a
  # formula. Checked before calling the chat model at all: cheaper, and
  # more reliable than asking the model to self-report confidence.
  CONFIDENCE_THRESHOLD = 0.6

  def self.call(question:, organization:)
    chunks = ChunkRetriever.call(question: question, organization: organization)

    if chunks.empty? || chunks.first.neighbor_distance > CONFIDENCE_THRESHOLD
      return Result.new(answer: nil, sources: [], escalated?: true)
    end

    answer = ChatCompletionService.call(build_prompt(question, chunks))

    Result.new(answer: answer, sources: chunks.map(&:document).uniq, escalated?: false)
  end

  def self.build_prompt(question, chunks)
    context = chunks.each_with_index.map { |chunk, i| "[#{i + 1}] #{chunk.content}" }.join("\n\n")

    <<~PROMPT
      Answer the question using only the context below. If the context
      doesn't contain the answer, say you don't know -- don't guess.

      Context:
      #{context}

      Question: #{question}
    PROMPT
  end
  private_class_method :build_prompt
end
