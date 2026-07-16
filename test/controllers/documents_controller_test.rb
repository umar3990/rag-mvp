require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "index lists only the current user's organization's documents" do
    get documents_path
    assert_response :success
    assert_match documents(:one).title, response.body
    assert_no_match documents(:two).title, response.body
  end

  test "new renders the upload form" do
    get new_document_path
    assert_response :success
  end

  test "create uploads a document and enqueues processing" do
    assert_difference "Document.count", 1 do
      assert_enqueued_with(job: DocumentProcessingJob) do
        post documents_path, params: {
          document: {
            title: "New handbook",
            file: fixture_file_upload("sample.txt", "text/plain")
          }
        }
      end
    end

    document = Document.order(:created_at).last
    assert_equal @user.organization, document.organization
    assert_equal @user, document.user
    assert_redirected_to documents_path
  end

  test "create rejects an unsupported file type without creating a record" do
    assert_no_difference "Document.count" do
      post documents_path, params: {
        document: {
          title: "Bad upload",
          file: fixture_file_upload("sample.txt", "text/html")
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "show 404s for a document belonging to another organization" do
    get document_path(documents(:two))
    assert_response :not_found
  end

  test "show displays extracted chunks once processing is complete" do
    document = Document.create!(
      title: "Handbook", organization: @user.organization,
      file: { io: StringIO.new("hello from a chunked document"), filename: "note.txt", content_type: "text/plain" }
    )
    VCR.use_cassette("documents_controller/show_displays_chunks") do
      perform_enqueued_jobs only: DocumentProcessingJob
    end

    get document_path(document)

    assert_response :success
    assert_match "hello from a chunked document", response.body
  end

  test "retry re-enqueues processing for a failed document" do
    document = Document.create!(
      title: "Handbook", organization: @user.organization,
      file: { io: StringIO.new("hello"), filename: "note.txt", content_type: "text/plain" }
    )
    document.update_column(:status, :failed)

    assert_enqueued_with(job: DocumentProcessingJob) do
      post retry_document_path(document)
    end

    assert_redirected_to document_path(document)
    assert document.reload.pending?
  end

  test "retry refuses a document that isn't failed" do
    document = Document.create!(
      title: "Handbook", organization: @user.organization,
      file: { io: StringIO.new("hello"), filename: "note.txt", content_type: "text/plain" }
    )
    document.update_column(:status, :completed)

    assert_no_enqueued_jobs only: DocumentProcessingJob do
      post retry_document_path(document)
    end

    assert_redirected_to document_path(document)
    assert document.reload.completed?
  end
end
