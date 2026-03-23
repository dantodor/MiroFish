defmodule Miroex.AI.JSONHelper do
  @moduledoc """
  Helper module for JSON parsing with error recovery.
  Handles truncated JSON, malformed strings, and provides fallback extraction.
  """

  @doc """
  Attempt to decode JSON, falling back to partial extraction on failure.

  ## Options
    - `:required_fields` - List of required field names for fallback extraction
    - `:fallback` - Default value to return if all parsing fails

  ## Examples
      iex> JSONHelper.parse_with_fallback(~s({"name": "test", "value": 123}))
      {:ok, %{"name" => "test", "value" => 123}}

      iex> JSONHelper.parse_with_fallback("not json", fallback: %{"default" => true})
      {:ok, %{"default" => true}}
  """
  @spec parse_with_fallback(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def parse_with_fallback(content, opts \\ []) when is_binary(content) do
    required_fields = Keyword.get(opts, :required_fields, ["bio", "persona", "name", "type"])
    fallback = Keyword.get(opts, :fallback, %{})

    result =
      try do
        trimmed = String.trim(content)

        case Jason.decode(trimmed) do
          {:ok, result} when is_map(result) ->
            {:ok, result}

          {:ok, result} when is_list(result) ->
            {:ok, %{"items" => result}}

          {:error, _} ->
            fixed = fix_truncated_json(trimmed)

            case Jason.decode(fixed) do
              {:ok, result} when is_map(result) -> {:ok, result}
              _ -> :fallback
            end
        end
      rescue
        _ -> :fallback
      end

    case result do
      {:ok, data} ->
        {:ok, data}

      :fallback ->
        extracted = extract_partial_json(String.trim(content), required_fields)
        if extracted != %{}, do: {:ok, extracted}, else: {:ok, fallback}
    end
  end

  @doc """
  Attempt to decode JSON, raising on failure.
  """
  @spec parse!(String.t()) :: map() | list()
  def parse!(content) do
    content
    |> fix_truncated_json()
    |> Jason.decode!()
  end

  @doc """
  Fix truncated JSON by closing open brackets and braces.
  Handles common truncation patterns.
  """
  @spec fix_truncated_json(String.t()) :: String.t()
  def fix_truncated_json(content) when is_binary(content) do
    content
    |> String.trim()
    |> close_open_brackets()
    |> close_open_braces()
    |> close_unclosed_strings()
  end

  defp close_open_brackets(content) do
    open_count = content |> String.graphemes() |> Enum.count(&(&1 == "["))
    close_count = content |> String.graphemes() |> Enum.count(&(&1 == "]"))
    diff = open_count - close_count

    if diff > 0 do
      content <> String.duplicate("]", diff)
    else
      content
    end
  end

  defp close_open_braces(content) do
    open_count = content |> String.graphemes() |> Enum.count(&(&1 == "{"))
    close_count = content |> String.graphemes() |> Enum.count(&(&1 == "}"))
    diff = open_count - close_count

    if diff > 0 do
      content <> String.duplicate("}", diff)
    else
      content
    end
  end

  defp close_unclosed_strings(content) do
    trimmed = String.trim(content)
    last_char = if trimmed != "", do: String.last(trimmed), else: nil

    cond do
      last_char == nil -> content
      last_char in [?", ?'] -> content <> last_char
      true -> content
    end
  end

  @doc """
  Extract specific fields from potentially malformed JSON using regex.
  Used as fallback when normal parsing fails.
  """
  @spec extract_field(String.t(), String.t()) :: {:ok, String.t()} | :error
  def extract_field(content, field_name) when is_binary(content) and is_binary(field_name) do
    pattern = ~r/"#{field_name}"\s*:\s*"([^"]*)"/

    case Regex.run(pattern, content) do
      [_, value] ->
        {:ok, String.trim(value)}

      _ ->
        :error
    end
  rescue
    _ -> :error
  end

  @doc """
  Extract multiple fields from potentially malformed JSON.
  """
  @spec extract_fields(String.t(), [String.t()]) :: {:ok, map()} | :error
  def extract_fields(content, field_names) when is_binary(content) and is_list(field_names) do
    results =
      Enum.map(field_names, fn name ->
        {name, extract_field(content, name)}
      end)

    if Enum.any?(results, fn {_, v} -> v != :error end) do
      extracted =
        results
        |> Enum.reject(fn {_, v} -> v == :error end)
        |> Enum.map(fn {k, {:ok, v}} -> {k, v} end)
        |> Map.new()

      {:ok, extracted}
    else
      :error
    end
  end

  defp extract_partial_json(content, required_fields) when required_fields == [] do
    extract_partial_json(content, ["bio", "persona", "name", "type"])
  end

  defp extract_partial_json(content, field_names) do
    case extract_fields(content, field_names) do
      {:ok, extracted} -> extracted
      :error -> %{}
    end
  end

  @doc """
  Extract array from JSON string that may be truncated.
  """
  @spec extract_array(String.t(), String.t()) :: {:ok, [any()]} | :error
  def extract_array(content, field_name) when is_binary(content) and is_binary(field_name) do
    pattern = ~s/"#{field_name}"\\s*:\\s*\\[([^\\]]*(?:\\.[^\\]]*)*)\\]/

    case Regex.run(pattern, content) do
      [_, array_content] ->
        items =
          array_content
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(&strip_quotes/1)

        {:ok, items}

      _ ->
        :error
    end
  rescue
    _ -> :error
  end

  defp strip_quotes(value) do
    value
    |> String.trim()
    |> String.replace(~r/^"|"$/, "")
  end

  @doc """
  Encode a map to JSON, handling non-standard types gracefully.
  """
  @spec safe_encode(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def safe_encode(map, opts \\ []) do
    Jason.encode(map, opts)
  rescue
    _ ->
      cleaned = sanitize_for_encoding(map)
      Jason.encode(cleaned, opts)
  end

  defp sanitize_for_encoding(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {k, sanitize_value(v)} end)
    |> Map.new()
  end

  defp sanitize_for_encoding(list) when is_list(list) do
    Enum.map(list, &sanitize_value/1)
  end

  defp sanitize_value(v) when is_binary(v), do: v
  defp sanitize_value(v) when is_atom(v), do: Atom.to_string(v)
  defp sanitize_value(v) when is_integer(v), do: v
  defp sanitize_value(v) when is_float(v), do: v
  defp sanitize_value(v) when is_boolean(v), do: v
  defp sanitize_value(v) when is_nil(v), do: nil
  defp sanitize_value(v) when is_map(v), do: sanitize_for_encoding(v)
  defp sanitize_value(v) when is_list(v), do: sanitize_for_encoding(v)
  defp sanitize_value(v) when is_function(v), do: inspect(v)
  defp sanitize_value(v), do: inspect(v)
end
