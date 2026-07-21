require "test_helper"

class MessageReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @conversation = Conversation.create!(
      organization: @user.organization, source: :email,
      from_email: "customer@example.com", gmail_thread_id: "18abz9y3f2e1c0d4"
    )
    @conversation.messages.create!(role: :user, content: "What's your return policy?", gmail_message_id: "<q@mail.gmail.com>")
    @reply = @conversation.messages.create!(
      role: :assistant, escalated: false, review_status: :pending,
      content: "Returns are accepted within 30 days."
    )
  end

  test "index lists pending email replies, not web chat replies" do
    web_conversation = conversations(:one)

    get reviews_path
    assert_response :success
    assert_match @reply.content, response.body
    assert_no_match messages(:two).content, response.body
  end

  test "index never shows another organization's pending reviews" do
    other_conversation = Conversation.create!(
      organization: organizations(:two), source: :email,
      from_email: "someone@example.com", gmail_thread_id: "other-thread"
    )
    other_reply = other_conversation.messages.create!(
      role: :assistant, escalated: false, review_status: :pending, content: "Some other org's draft"
    )

    get reviews_path
    assert_no_match other_reply.content, response.body
  end

  test "approve updates content, marks approved, records the reviewer, and enqueues sending" do
    assert_enqueued_with(job: SendApprovedReplyJob) do
      patch approve_review_path(@reply), params: { content: "Edited: returns within 30 days with a receipt." }
    end

    @reply.reload
    assert_equal "Edited: returns within 30 days with a receipt.", @reply.content
    assert @reply.review_status_approved?
    assert_equal @user, @reply.reviewed_by
    assert_not_nil @reply.reviewed_at
    assert_redirected_to reviews_path
  end

  test "approve without editing keeps the original content" do
    patch approve_review_path(@reply), params: { content: @reply.content }
    assert_equal "Returns are accepted within 30 days.", @reply.reload.content
  end

  test "reject marks rejected and records the reviewer without changing content" do
    patch reject_review_path(@reply)

    @reply.reload
    assert @reply.review_status_rejected?
    assert_equal @user, @reply.reviewed_by
    assert_not_nil @reply.reviewed_at
    assert_equal "Returns are accepted within 30 days.", @reply.content
  end

  test "404s approving a message belonging to another organization" do
    other_conversation = Conversation.create!(
      organization: organizations(:two), source: :email,
      from_email: "someone@example.com", gmail_thread_id: "other-thread"
    )
    other_reply = other_conversation.messages.create!(
      role: :assistant, escalated: false, review_status: :pending, content: "Not yours"
    )

    patch approve_review_path(other_reply), params: { content: "hijacked" }
    assert_response :not_found
  end

  test "404s approving a message that's already been reviewed" do
    @reply.update!(review_status: :approved, reviewed_by: @user, reviewed_at: Time.current)

    patch approve_review_path(@reply), params: { content: "too late" }
    assert_response :not_found
  end
end
