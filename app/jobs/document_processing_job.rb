# Text extraction and chunking land in the next increment. For now this
# just proves the upload -> background job pipeline actually works end
# to end: a document starts "pending" and this job flips it to
# "completed" once it's run, off the request/response cycle.
class DocumentProcessingJob < ApplicationJob
  queue_as :default

  def perform(document)
    # update_column, not the enum bang method (processing!/completed!) --
    # those call update! and re-run every validation, including "file
    # must be attached." That was already validated when the document
    # was first saved; a status transition shouldn't re-check it.
    document.update_column(:status, :processing)
    # TODO: extract text (pdf-reader), chunk it, store Chunk records.
    document.update_column(:status, :completed)
  end
end
