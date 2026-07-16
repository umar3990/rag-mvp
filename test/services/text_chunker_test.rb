require "test_helper"

class TextChunkerTest < ActiveSupport::TestCase
  test "returns an empty array for blank text" do
    assert_equal [], TextChunker.call("")
    assert_equal [], TextChunker.call(nil)
  end

  test "returns a single chunk when text is shorter than chunk_size" do
    text = (1..10).map { |n| "word#{n}" }.join(" ")
    chunks = TextChunker.call(text, chunk_size: 500, overlap: 50)

    assert_equal 1, chunks.length
    assert_equal text, chunks.first
  end

  test "splits into multiple chunks with overlapping words at the boundary" do
    words = (1..120).map { |n| "word#{n}" }
    chunks = TextChunker.call(words.join(" "), chunk_size: 100, overlap: 20)

    assert_equal 2, chunks.length
    assert_equal words[0, 100].join(" "), chunks[0]
    # second chunk starts 80 words in (chunk_size - overlap), so the last
    # 20 words of chunk 1 reappear as the first 20 of chunk 2
    assert_equal words[80, 40].join(" "), chunks[1]
  end
end
