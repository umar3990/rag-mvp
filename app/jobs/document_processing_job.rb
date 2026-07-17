class DocumentProcessingJob < ApplicationJob
  queue_as :default

  # retry_on/discard_on handlers are searched bottom-to-top (most
  # recently declared first) -- discard_on must come *after* retry_on so
  # its more specific match (UnsupportedContentType is a StandardError)
  # gets checked before the generic StandardError handler below would
  # otherwise catch it first and retry something that will never succeed.

  # Everything else (a flaky read, a future embeddings API timeout) might
  # succeed on a later attempt. Retry with growing delays between tries;
  # only mark the document failed once every attempt is exhausted -- the
  # block only runs at that point, not on each individual failure.
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, _error|
    mark_status(job.arguments.first, :failed)
  end

  # UnsupportedContentType is permanent -- the same file will never
  # extract successfully no matter how many times we retry, so fail
  # immediately rather than wasting attempts.
  discard_on TextExtractor::UnsupportedContentType do |job, _error|
    mark_status(job.arguments.first, :failed)
  end

  def self.mark_status(document, status)
    # save!(validate: false), not update_column -- update_column skips
    # every AR callback, including the after_commit hooks Turbo's
    # broadcasts_to/broadcasts_refreshes rely on to push live updates to
    # the browser. save!(validate: false) still skips validation (the
    # file-attached check was already done when the document was first
    # saved) but keeps callbacks running.
    document.status = status
    document.save!(validate: false)
  end

  def perform(document)
    self.class.mark_status(document, :processing)

    text = TextExtractor.call(document)
    chunk_contents = TextChunker.call(text)

    # Wrapped in a transaction so a document is never left with a
    # partial set of chunks if something fails midway.
    Chunk.transaction do
      document.chunks.destroy_all
      chunk_contents.each_with_index do |content, position|
        embedding = EmbeddingService.call(content)
        document.chunks.create!(
          organization: document.organization, content: content, position: position, embedding: embedding
        )
      end
    end

    self.class.mark_status(document, :completed)
  end
end
