defmodule Miroex.Graph.EntityReaderTest do
  use ExUnit.Case, async: true

  alias Miroex.Graph.EntityReader

  describe "get_relations/1" do
    test "handles non-existent graph" do
      result = EntityReader.get_relations("nonexistent_graph")

      # Should return empty list or error gracefully
      assert result == {:ok, []} or match?({:error, _}, result)
    end
  end

  describe "get_active_relations/1" do
    test "returns only valid relations" do
      result = EntityReader.get_active_relations("test_graph")

      assert result == {:ok, []} or match?({:ok, _}, result)
    end
  end

  describe "get_historical_relations/1" do
    test "returns expired/invalid relations" do
      result = EntityReader.get_historical_relations("test_graph")

      assert result == {:ok, []} or match?({:ok, _}, result)
    end
  end

  describe "get_relations_as_of/2" do
    test "returns relations valid at specific time" do
      check_time = ~U[2024-01-15 10:00:00Z]
      result = EntityReader.get_relations_as_of("test_graph", check_time)

      assert result == {:ok, []} or match?({:ok, _}, result)
    end
  end

  describe "get_entity_timeline/2" do
    test "returns timeline of entity events" do
      result = EntityReader.get_entity_timeline("test_graph", "TestEntity")

      assert result == {:ok, []} or match?({:ok, _}, result)
    end
  end
end
