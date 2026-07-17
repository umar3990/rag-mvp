require "net/http"
require "json"

# Calls a local Ollama server for chat completion -- $0 cost, no API key,
# same local install as EmbeddingService. Single-shot: one prompt in, one
# reply out, no conversation history or tool-calling (see CLAUDE.md's
# "Deliberately deferred" -- the MVP's "AI Agent" step is one RAG call
# plus a confidence check, not an agentic loop).
class ChatCompletionService
  class RequestFailed < StandardError; end

  def self.call(prompt)
    uri = URI.join(ENV.fetch("OLLAMA_URL"), "/api/chat")
    response = Net::HTTP.post(
      uri,
      {
        model: ENV.fetch("OLLAMA_CHAT_MODEL"),
        messages: [ { role: "user", content: prompt } ],
        stream: false
      }.to_json,
      "Content-Type" => "application/json"
    )

    raise RequestFailed, "Ollama returned #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig("message", "content")
  end
end
