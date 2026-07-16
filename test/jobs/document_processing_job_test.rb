require "test_helper"

class DocumentProcessingJobTest < ActiveJob::TestCase
  test "extracts text, creates chunks, and marks the document completed" do
    document = Document.create!(
      title: "Handbook", organization: organizations(:one),
      file: { io: StringIO.new((1..1200).map { |n| "word#{n}" }.join(" ")), filename: "handbook.txt", content_type: "text/plain" }
    )

    # Real embedding calls hit the local Ollama server -- record: :once
    # (test_helper.rb) means this only touches the network the first time;
    # every run after that replays the committed cassette.
    VCR.use_cassette("document_processing_job/embeds_chunks") do
      DocumentProcessingJob.perform_now(document)
    end

    document.reload
    assert document.completed?
    assert_equal 3, document.chunks.count
    assert_equal 0, document.chunks.first.position
    assert_equal 768, document.chunks.first.embedding.size
  end

  test "discards immediately for a permanently unsupported content type" do
    document = Document.new(title: "Bad upload", organization: organizations(:one))
    document.file.attach(io: StringIO.new("<html></html>"), filename: "page.html", content_type: "text/html")
    document.save!(validate: false)

    # discard_on catches the error and marks failed without raising or
    # scheduling a retry -- an unsupported file type will never succeed
    # no matter how many times we try it.
    DocumentProcessingJob.perform_now(document)

    assert document.reload.failed?
  end

  test "retries on a transient error instead of failing immediately" do
    document = Document.create!(
      title: "Handbook", organization: organizations(:one),
      file: { io: StringIO.new("hello"), filename: "note.txt", content_type: "text/plain" }
    )

    original_method = TextExtractor.method(:call)
    begin
      TextExtractor.define_singleton_method(:call) { |*| raise "boom" }

      assert_enqueued_with(job: DocumentProcessingJob) do
        DocumentProcessingJob.perform_now(document)
      end
    ensure
      TextExtractor.define_singleton_method(:call, original_method)
    end

    # Still "processing", not "failed" -- the failed status only gets set
    # once every retry attempt is exhausted, not on the first failure.
    assert document.reload.processing?
  end
end
