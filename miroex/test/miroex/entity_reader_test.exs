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

  describe "delete_graph/1" do
    test "handles non-existent graph gracefully" do
      result = EntityReader.delete_graph("nonexistent")
      assert match?({:error, _}, result)
    end
  end
end
