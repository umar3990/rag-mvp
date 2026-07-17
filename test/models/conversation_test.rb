require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "orders messages oldest first" do
    conversation = conversations(:one)
    assert_equal [ messages(:one), messages(:two) ], conversation.messages.to_a
  end

  test "destroying a conversation destroys its messages" do
    conversation = conversations(:one)
    assert_difference -> { Message.count }, -2 do
      conversation.destroy
    end
  end
end
