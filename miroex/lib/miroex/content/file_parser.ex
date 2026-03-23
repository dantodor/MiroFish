defmodule Miroex.Content.FileParser do
  @moduledoc """
  Parse uploaded files (PDF, MD, TXT) and extract text content.
  """

  @spec parse(binary(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def parse(file_content, filename) do
    ext = String.downcase(Path.extname(filename))

    case ext do
      ".txt" -> parse_text(file_content)
      ".md" -> parse_markdown(file_content)
      ".pdf" -> parse_pdf(file_content)
      _ -> {:error, "Unsupported file type: #{ext}"}
    end
  end

  defp parse_text(content) when is_binary(content) do
    {:ok, content}
  end

  defp parse_markdown(content) when is_binary(content) do
    html = Earmark.as_html!(content)
    text = HtmlSanitizeEx.strip_tags(html)
    {:ok, text}
  end

  defp parse_pdf(content) when is_binary(content) do
    case System.cmd("pdftotext", ["-", "-"], stdin: content) do
      {text, 0} when is_binary(text) -> {:ok, text}
      {error, _} -> {:error, "PDF parsing failed: #{error}"}
    end
  end

  @spec extract_chunks(String.t(), integer(), integer()) :: [String.t()]
  def extract_chunks(text, chunk_size \\ 1000, overlap \\ 200) do
    text
    |> String.split(["\n\n", "\n", ". "], trim: false)
    |> Enum.chunk_every(chunk_size, overlap, :discard)
    |> Enum.map(&Enum.join(&1, " "))
    |> Enum.reject(&(&1 == "" or String.length(&1) < 50))
  end
end
