require "test_helper"

class TextExtractorTest < ActiveSupport::TestCase
  # Each test builds its own Document (rather than reusing one fixture and
  # re-attaching) -- replacing an existing attachment on the same record
  # doesn't reliably write the new file in this environment; a fresh
  # attach on a document that's never had one does.
  def document_with(io:, filename:, content_type:)
    document = Document.new(title: "t", organization: organizations(:one))
    document.file.attach(io: io, filename: filename, content_type: content_type)
    # skip_validation: TextExtractor is tested independently of Document's
    # own content-type validation (which would reject text/html outright).
    document.save!(validate: false)
    document
  end

  test "extracts text from a plain text document" do
    document = document_with(io: StringIO.new("hello from a text file"), filename: "note.txt", content_type: "text/plain")

    assert_equal "hello from a text file", TextExtractor.call(document)
  end

  test "extracts text from a PDF document" do
    pdf_path = Rails.root.join("tmp", "text_extractor_test_#{SecureRandom.hex(4)}.pdf")
    Prawn::Document.generate(pdf_path.to_s) { |pdf| pdf.text "Hello from a PDF" }

    document = document_with(io: File.open(pdf_path), filename: "note.pdf", content_type: "application/pdf")

    assert_match "Hello from a PDF", TextExtractor.call(document)
  ensure
    FileUtils.rm_f(pdf_path)
  end

  test "raises for an unsupported content type" do
    document = document_with(io: StringIO.new("<html></html>"), filename: "page.html", content_type: "text/html")

    assert_raises(TextExtractor::UnsupportedContentType) do
      TextExtractor.call(document)
    end
  end
end
