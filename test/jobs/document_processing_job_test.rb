require "test_helper"

class DocumentProcessingJobTest < ActiveJob::TestCase
  test "extracts text, creates chunks, and marks the document completed" do
    document = Document.create!(
      title: "Handbook", organization: organizations(:one),
      file: { io: StringIO.new((1..1200).map { |n| "word#{n}" }.join(" ")), filename: "handbook.txt", content_type: "text/plain" }
    )

    DocumentProcessingJob.perform_now(document)

    document.reload
    assert document.completed?
    assert_equal 3, document.chunks.count
    assert_equal 0, document.chunks.first.position
  end

  test "marks the document failed and re-raises when extraction errors" do
    document = Document.create!(
      title: "Handbook", organization: organizations(:one),
      file: { io: StringIO.new("hello"), filename: "note.txt", content_type: "text/plain" }
    )

    original_method = TextExtractor.method(:call)
    begin
      TextExtractor.define_singleton_method(:call) { |*| raise "boom" }
      assert_raises(RuntimeError) { DocumentProcessingJob.perform_now(document) }
    ensure
      TextExtractor.define_singleton_method(:call, original_method)
    end

    assert document.reload.failed?
  end
end
