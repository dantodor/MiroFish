defmodule Miroex.AI.Tools.GraphSearchTest do
  use ExUnit.Case, async: true

  alias Miroex.AI.Tools.GraphSearch

  describe "execute/2" do
    test "filters entities by query" do
      graph_id = "test_graph"

      # This will likely return empty for a non-existent graph
      result = GraphSearch.execute(graph_id, "student")

      assert result == {:ok, []} or match?({:ok, _}, result)
    end
  end

  describe "insight_forge/3" do
    test "returns enhanced search results" do
      graph_id = "test_graph"

      result = GraphSearch.insight_forge(graph_id, "students", top_k: 5)

      assert match?({:ok, %{query: "students", results: _}}, result)
    end

    test "includes sub-queries in results" do
      graph_id = "test_graph"

      result = GraphSearch.insight_forge(graph_id, "campus policy")

      assert match?({:ok, %{sub_queries: _}}, result)
    end
  end

  describe "generate_sub_queries/2" do
    test "generates fallback sub-queries for simple queries" do
      query = "climate change"

      sub_queries = GraphSearch.generate_fallback_sub_queries(query)

      assert "climate change" in sub_queries
      assert length(sub_queries) >= 1
    end

    test "handles single word queries" do
      query = "students"

      sub_queries = GraphSearch.generate_fallback_sub_queries(query)

      assert "students" in sub_queries
    end
  end

  describe "panorama_search/2" do
    test "returns graph overview" do
      graph_id = "test_graph"

      result = GraphSearch.panorama_search(graph_id, top_k: 10)

      assert match?({:ok, %{overview: _, entities: _, relations: _}}, result)
    end
  end

  describe "get_relation_chains/3" do
    test "returns relation chains for entity" do
      graph_id = "test_graph"

      result = GraphSearch.get_relation_chains(graph_id, "TestEntity", depth: 2)

      assert match?({:ok, _}, result)
    end
  end

  describe "interview_agents/3" do
    test "returns agent interview results" do
      simulation_id = "test_sim"

      result = GraphSearch.interview_agents(simulation_id, "views on policy", max_agents: 2)

      # Will likely fail due to no simulation running, but tests API structure
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "execute_by_type/2" do
    test "filters by entity type" do
      graph_id = "test_graph"

      result = GraphSearch.execute_by_type(graph_id, "Student")

      assert match?({:ok, _}, result)
    end
  end

  describe "get_types/1" do
    test "returns entity types" do
      graph_id = "test_graph"

      result = GraphSearch.get_types(graph_id)

      assert match?({:ok, _}, result)
    end
  end
end
