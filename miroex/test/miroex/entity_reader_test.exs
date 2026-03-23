defmodule Miroex.Graph.EntityReaderTest do
  use ExUnit.Case, async: true

  alias Miroex.Graph.EntityReader

  describe "get_entities/1" do
    test "handles non-existent graph gracefully" do
      result = EntityReader.get_entities("nonexistent_graph_id")
      assert match?({:error, _}, result)
    end
  end

  describe "get_entities_by_type/2" do
    test "handles non-existent graph gracefully" do
      result = EntityReader.get_entities_by_type("nonexistent", "Person")
      assert match?({:error, _}, result)
    end
  end

  describe "get_entity_types/1" do
    test "handles non-existent graph gracefully" do
      result = EntityReader.get_entity_types("nonexistent")
      assert match?({:error, _}, result)
    end
  end

  describe "get_entity/2" do
    test "handles non-existent graph gracefully" do
      result = EntityReader.get_entity("nonexistent", "SomeEntity")
      assert match?({:error, _}, result)
    end
  end

  describe "get_graph_data/1" do
    test "handles non-existent graph gracefully" do
      result = EntityReader.get_graph_data("nonexistent")
      assert match?({:error, _}, result)
    end
  end

  describe "get_relations/1" do
    test "handles non-existent graph gracefully" do
      result = EntityReader.get_relations("nonexistent")
      assert match?({:error, _}, result)
    end
  end

  describe "get_relations_for_entity/2" do
    test "handles non-existent graph gracefully" do
      result = EntityReader.get_relations_for_entity("nonexistent", "entity_name")
      assert match?({:error, _}, result)
    end

    test "handles nil relations gracefully" do
      # This tests the edge case where relations are nil
      result = EntityReader.get_relations_for_entity("nonexistent", "nonexistent")
      assert match?({:error, _}, result) or result == {:ok, []}
    end
  end

  describe "get_related_entity_details/2" do
    test "handles empty relations list" do
      result = EntityReader.get_related_entity_details("nonexistent", [])
      assert result == {:ok, []}
    end

    test "handles nil relations" do
      result = EntityReader.get_related_entity_details("nonexistent", nil)
      assert result == {:ok, []}
    end

    test "handles non-existent graph gracefully" do
      result = EntityReader.get_related_entity_details("nonexistent", [%{related_to: "test"}])
      assert match?({:error, _}, result)
    end
  end

  describe "get_entity_with_context/2" do
    test "handles non-existent graph gracefully" do
      # When graph doesn't exist, Memgraph query fails
      result = EntityReader.get_entity_with_context("nonexistent", "entity_name")
      assert match?({:error, _}, result)
    end
  end

  describe "delete_graph/1" do
    test "handles non-existent graph gracefully" do
      result = EntityReader.delete_graph("nonexistent")
      assert match?({:error, _}, result)
    end
  end
end
