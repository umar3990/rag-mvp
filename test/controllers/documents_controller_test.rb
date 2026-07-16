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
end
