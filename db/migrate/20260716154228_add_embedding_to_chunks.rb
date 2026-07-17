class AddEmbeddingToChunks < ActiveRecord::Migration[8.1]
  def change
    # 768 dims -- nomic-embed-text's output size (Ollama, local, $0 cost).
    add_column :chunks, :embedding, :vector, limit: 768
  end
end
