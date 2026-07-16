require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "requires a title" do
    document = Document.new(organization: organizations(:one))
    assert_not document.valid?
    assert_includes document.errors[:title], "can't be blank"
  end

  test "requires an organization" do
    document = Document.new(title: "Handbook")
    assert_not document.valid?
    assert_includes document.errors[:organization], "must exist"
  end

  test "survives its uploading user being deleted" do
    document = documents(:one)
    uploader = document.user
    uploader.destroy

    assert document.reload.persisted?
    assert_nil document.user_id
  end

  test "requires a file" do
    document = Document.new(title: "Handbook", organization: organizations(:one))
    assert_not document.valid?
    assert_includes document.errors[:file], "must be attached"
  end

  test "rejects an unsupported content type" do
    document = Document.new(title: "Handbook", organization: organizations(:one))
    document.file.attach(
      io: StringIO.new("<html></html>"), filename: "page.html", content_type: "text/html"
    )

    assert_not document.valid?
    assert_includes document.errors[:file], "must be a PDF or plain text file"
  end

  test "starts pending and enqueues processing once saved" do
    document = Document.new(title: "Handbook", organization: organizations(:one))
    document.file.attach(
      io: File.open(file_fixture("sample.txt")), filename: "sample.txt", content_type: "text/plain"
    )

    assert document.pending?

    assert_enqueued_with(job: DocumentProcessingJob) do
      document.save!
    end
  end
end
