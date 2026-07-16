require "test_helper"

class ChunkTest < ActiveSupport::TestCase
  test "requires content" do
    chunk = Chunk.new(document: documents(:one), organization: organizations(:one), position: 0)
    assert_not chunk.valid?
    assert_includes chunk.errors[:content], "can't be blank"
  end

  test "requires a unique position within the same document" do
    chunk = Chunk.new(
      document: documents(:one), organization: organizations(:one),
      content: "text", position: chunks(:one).position
    )
    assert_not chunk.valid?
    assert_includes chunk.errors[:position], "has already been taken"
  end

  test "the same position is fine on a different document" do
    other_document = Document.create!(
      title: "Another handbook", organization: organizations(:one),
      file: { io: StringIO.new("x"), filename: "a.txt", content_type: "text/plain" }
    )

    chunk = Chunk.new(
      document: other_document, organization: organizations(:one),
      content: "text", position: chunks(:one).position
    )
    assert chunk.valid?
  end
end
