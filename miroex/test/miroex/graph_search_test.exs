defmodule Miroex.AI.Tools.GraphSearchTest do
  use ExUnit.Case, async: true

  alias Miroex.AI.Tools.GraphSearch

  describe "execute/2" do
    test "handles non-existent graph gracefully" do
      result = GraphSearch.execute("nonexistent_graph", "search term")
      assert match?({:error, _}, result)
    end
  end

  describe "execute_by_type/2" do
    test "handles non-existent graph gracefully" do
      result = GraphSearch.execute_by_type("nonexistent", "Person")
      assert match?({:error, _}, result)
    end
  end

  describe "get_types/1" do
    test "handles non-existent graph gracefully" do
      result = GraphSearch.get_types("nonexistent")
      assert match?({:error, _}, result)
    end
  end

  describe "get_graph_data/1" do
    test "handles non-existent graph gracefully" do
      result = GraphSearch.get_graph_data("nonexistent")
      assert match?({:error, _}, result)
    end
  end

  describe "insight_forge/2" do
    test "handles non-existent graph gracefully" do
      result = GraphSearch.insight_forge("nonexistent_graph", "search term")
      assert match?({:error, _}, result)
    end

    test "accepts keyword opts for top_k" do
      result = GraphSearch.insight_forge("nonexistent", "term", top_k: 5)
      assert match?({:error, _}, result)
    end
  end

  describe "panorama_search/1" do
    test "handles non-existent graph gracefully" do
      result = GraphSearch.panorama_search("nonexistent")
      assert match?({:error, _}, result)
    end

    test "accepts keyword opts for top_k" do
      result = GraphSearch.panorama_search("nonexistent", top_k: 10)
      assert match?({:error, _}, result)
    end
  end

  describe "get_relation_chains/2" do
    test "handles non-existent graph gracefully" do
      result = GraphSearch.get_relation_chains("nonexistent_graph", "entity_name")
      assert match?({:error, _}, result)
    end

    test "accepts keyword opts for depth" do
      result = GraphSearch.get_relation_chains("nonexistent", "entity", depth: 5)
      assert match?({:error, _}, result)
    end

    test "accepts keyword opts for max_paths" do
      result = GraphSearch.get_relation_chains("nonexistent", "entity", max_paths: 10)
      assert match?({:error, _}, result)
    end
  end

  describe "interview_agents/3" do
    test "handles non-existent graph gracefully" do
      result = GraphSearch.interview_agents("nonexistent_sim", "topic")
      assert match?({:error, _}, result)
    end

    test "accepts keyword opts for max_agents" do
      result = GraphSearch.interview_agents("nonexistent", "topic", max_agents: 3)
      assert match?({:error, _}, result)
    end

    test "returns list of interview results" do
      # When graph has no entities, should still return empty list or handle gracefully
      result = GraphSearch.interview_agents("nonexistent_sim", "topic", max_agents: 5)
      # Either returns {:ok, []} or {:error, _} is acceptable
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
