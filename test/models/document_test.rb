require "test_helper"

class DocumentTest < ActiveSupport::TestCase
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
end
