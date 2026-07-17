require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "requires content" do
    message = Message.new(conversation: conversations(:one), role: :user)
    assert_not message.valid?
    assert_includes message.errors[:content], "can't be blank"
  end

  test "requires a valid role" do
    assert_raises(ArgumentError) do
      Message.new(conversation: conversations(:one), role: :bot, content: "hi")
    end
  end

  test "tracks which documents an assistant reply drew its answer from" do
    message = messages(:two)
    message.source_documents << documents(:one)

    assert_equal [ documents(:one) ], message.reload.source_documents
  end
end
