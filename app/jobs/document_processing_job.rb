class DocumentProcessingJob < ApplicationJob
  queue_as :default

  def perform(document)
    # update_column, not the enum bang method (processing!/completed!) --
    # those call update! and re-run every validation, including "file
    # must be attached." That was already validated when the document
    # was first saved; a status transition shouldn't re-check it.
    document.update_column(:status, :processing)

    text = TextExtractor.call(document)
    chunk_contents = TextChunker.call(text)

    # Wrapped in a transaction so a document is never left with a
    # partial set of chunks if something fails midway.
    Chunk.transaction do
      document.chunks.destroy_all
      chunk_contents.each_with_index do |content, position|
        document.chunks.create!(organization: document.organization, content: content, position: position)
      end
    end

    document.update_column(:status, :completed)
  rescue StandardError
    document.update_column(:status, :failed)
    raise
  end
end
