defmodule Miroex.Content.FileParserTest do
  use ExUnit.Case, async: true

  alias Miroex.Content.FileParser

  describe "parse/2" do
    test "parses txt file" do
      content = "Hello, this is a test document."
      {:ok, result} = FileParser.parse(content, "test.txt")
      assert result == content
    end

    test "parses markdown file" do
      content = "# Hello\n\nThis is **bold** and *italic*."
      {:ok, result} = FileParser.parse(content, "test.md")
      assert is_binary(result)
      assert String.contains?(result, "Hello")
    end

    test "returns error for unsupported file type" do
      result = FileParser.parse("content", "test.xyz")
      assert result == {:error, "Unsupported file type: .xyz"}
    end
  end

  describe "extract_chunks/3" do
    test "splits text into chunks" do
      text =
        "This is a longer sentence one. This is a longer sentence two. This is a longer sentence three. Four. Five. Six."

      chunks = FileParser.extract_chunks(text, 3, 1)

      assert is_list(chunks)
      assert length(chunks) > 0
    end

    test "filters out short chunks" do
      text = "Short."
      chunks = FileParser.extract_chunks(text, 100, 20)
      assert chunks == []
    end

    test "handles empty text" do
      chunks = FileParser.extract_chunks("", 10, 2)
      assert chunks == []
    end

    test "respects chunk_size parameter" do
      text = String.duplicate("a ", 100) |> String.trim()
      chunks = FileParser.extract_chunks(text, 50, 10)

      chunks
      |> Enum.each(fn chunk ->
        assert String.length(chunk) <= 50 + 10
      end)
    end
  end
end
