# Splits extracted text into word-count-bounded chunks for embedding and
# retrieval. Word count is a rough, cheap proxy for token count (an exact
# tokenizer comes into play at the embeddings step, not here).
#
# Consecutive chunks overlap by a small window so an idea that happens to
# fall right on a chunk boundary isn't split with neither chunk capturing
# it well on its own.
class TextChunker
  DEFAULT_CHUNK_SIZE = 500
  DEFAULT_OVERLAP = 50

  def self.call(text, chunk_size: DEFAULT_CHUNK_SIZE, overlap: DEFAULT_OVERLAP)
    words = text.to_s.split(/\s+/)
    return [] if words.empty?

    step = chunk_size - overlap
    (0...words.length).step(step).map do |start|
      words[start, chunk_size].join(" ")
    end
  end
end
