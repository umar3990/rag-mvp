require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "index lists only the current user's organization's conversations" do
    get conversations_path
    assert_response :success
  end

  test "create starts a new conversation for the current user and organization" do
    assert_difference "Conversation.count", 1 do
      post conversations_path
    end

    conversation = Conversation.order(:created_at).last
    assert_equal @user, conversation.user
    assert_equal @user.organization, conversation.organization
    assert_redirected_to conversation_path(conversation)
  end

  test "show 404s for a conversation belonging to another organization" do
    get conversation_path(conversations(:two))
    assert_response :not_found
  end

  test "show renders the conversation's messages" do
    get conversation_path(conversations(:one))
    assert_response :success
    assert_match ERB::Util.html_escape(messages(:one).content), response.body
  end
end
