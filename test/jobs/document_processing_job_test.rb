require "test_helper"

class DocumentProcessingJobTest < ActiveJob::TestCase
  test "marks the document completed" do
    document = documents(:one)
    document.update_column(:status, "pending")

    DocumentProcessingJob.perform_now(document)

    assert document.reload.completed?
  end
end
