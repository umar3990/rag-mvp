require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @conversation = conversations(:one)
  end

  test "answers with a grounded reply and cites its sources when a good match exists" do
    chunk = Chunk.create!(
      document: documents(:one), organization: @user.organization,
      content: "Returns are accepted within 30 days of purchase with a receipt.", position: 100,
      embedding: unit_vector(0)
    )

    stub_embedding(unit_vector(0)) do
      stub_chat("Returns are accepted within 30 days.") do
        assert_difference "Message.count", 2 do
          post conversation_messages_path(@conversation),
            params: { message: { content: "What's the return policy?" } }, as: :turbo_stream
        end
      end
    end

    assert_response :success
    reply = @conversation.messages.assistant.order(:created_at).last
    assert_equal "Returns are accepted within 30 days.", reply.content
    assert_not reply.escalated?
    assert_equal [ chunk.document ], reply.source_documents
  end

  test "escalates instead of answering when nothing relevant is in the knowledge base" do
    stub_embedding(unit_vector(0)) do
      assert_difference "Message.count", 2 do
        post conversation_messages_path(@conversation),
        params: { message: { content: "What's the weather on Mars?" } }, as: :turbo_stream
      end
    end

    reply = @conversation.messages.assistant.order(:created_at).last
    assert reply.escalated?
    assert_equal MessagesController::NO_CONFIDENT_ANSWER, reply.content
  end

  test "rejects a blank message without generating a reply" do
    assert_no_difference "Message.count" do
      post conversation_messages_path(@conversation), params: { message: { content: "" } }
    end

    assert_response :unprocessable_entity
  end

  private

  def unit_vector(index)
    Array.new(768, 0.0).tap { |v| v[index] = 1.0 }
  end

  def stub_embedding(vector)
    original_method = EmbeddingService.method(:call)
    EmbeddingService.define_singleton_method(:call) { |*| vector }
    yield
  ensure
    EmbeddingService.define_singleton_method(:call, original_method)
  end

  def stub_chat(answer)
    original_method = ChatCompletionService.method(:call)
    ChatCompletionService.define_singleton_method(:call) { |*| answer }
    yield
  ensure
    ChatCompletionService.define_singleton_method(:call, original_method)
  end
end
