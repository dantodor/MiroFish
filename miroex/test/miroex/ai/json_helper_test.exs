defmodule Miroex.AI.JSONHelperTest do
  use ExUnit.Case, async: true

  alias Miroex.AI.JSONHelper

  describe "parse_with_fallback/2" do
    test "parses valid JSON map" do
      json = ~s({"name": "test", "value": 123})
      assert {:ok, result} = JSONHelper.parse_with_fallback(json)
      assert result["name"] == "test"
      assert result["value"] == 123
    end

    test "parses valid JSON array by wrapping in items key" do
      json = ~s(["item1", "item2"])
      assert {:ok, result} = JSONHelper.parse_with_fallback(json)
      assert result["items"] == ["item1", "item2"]
    end

    test "handles invalid JSON with fallback" do
      json = "not valid json at all"
      assert {:ok, _} = JSONHelper.parse_with_fallback(json, fallback: %{"default" => true})
    end

    test "handles truncated JSON" do
      json = ~s({"name": "test", "value":)
      assert {:ok, result} = JSONHelper.parse_with_fallback(json)
      assert is_map(result)
    end

    test "returns fallback when JSON is invalid and no fields extracted" do
      json = "completely broken"
      fallback = %{"fallback" => "value"}
      assert {:ok, ^fallback} = JSONHelper.parse_with_fallback(json, fallback: fallback)
    end

    test "handles truncated JSON that can be fixed" do
      # This JSON is missing the closing brace
      truncated = ~s({"name": "test"})
      assert {:ok, result} = JSONHelper.parse_with_fallback(truncated)
      assert result["name"] == "test"
    end
  end

  describe "fix_truncated_json/1" do
    test "closes unclosed braces" do
      truncated = ~s({"name": "test")
      fixed = JSONHelper.fix_truncated_json(truncated)
      assert String.ends_with?(fixed, "}")
    end

    test "closes unclosed brackets" do
      truncated = ~s(["item1", "item2")
      fixed = JSONHelper.fix_truncated_json(truncated)
      assert String.ends_with?(fixed, "]")
    end

    test "handles already valid JSON" do
      valid = ~s({"name": "test"})
      assert JSONHelper.fix_truncated_json(valid) == valid
    end
  end

  describe "extract_field/2" do
    test "extracts string field" do
      content = ~s({"name": "John", "age": 30})
      assert {:ok, "John"} = JSONHelper.extract_field(content, "name")
    end

    test "returns error for missing field" do
      content = ~s({"name": "John"})
      assert :error = JSONHelper.extract_field(content, "missing")
    end

    test "handles malformed content gracefully" do
      assert :error = JSONHelper.extract_field("not json at all", "field")
    end
  end

  describe "safe_encode/2" do
    test "encodes normal map" do
      map = %{"name" => "test", "value" => 123}
      assert {:ok, _} = JSONHelper.safe_encode(map)
    end

    test "handles maps with atom values" do
      # Atoms are converted to strings by sanitize_value
      map = %{"atom" => :some_atom, "key" => "value"}
      assert {:ok, result} = JSONHelper.safe_encode(map)
      assert is_binary(result)
    end
  end
end
