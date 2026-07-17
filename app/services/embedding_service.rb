require "net/http"
require "json"

# Calls a local Ollama server for text embeddings -- $0 cost, no API key.
# Same shape as a call to a cloud embeddings API would be, just pointed at
# localhost (docker-compose's `ollama` service) instead.
class EmbeddingService
  class RequestFailed < StandardError; end

  def self.call(text)
    uri = URI.join(ENV.fetch("OLLAMA_URL"), "/api/embeddings")
    response = Net::HTTP.post(
      uri,
      { model: ENV.fetch("OLLAMA_EMBEDDING_MODEL"), prompt: text }.to_json,
      "Content-Type" => "application/json"
    )

    raise RequestFailed, "Ollama returned #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("embedding")
  end
end
