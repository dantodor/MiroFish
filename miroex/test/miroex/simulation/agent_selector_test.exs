defmodule Miroex.Simulation.AgentSelectorTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.AgentSelector

  describe "select_agents/3" do
    test "returns empty selection when no entities" do
      # Mock the EntityReader to return empty list
      result = AgentSelector.select_agents("test_sim", "topic", 5)

      assert result.selected_agents == []
      assert result.reasoning == "No entities found in graph"
    end

    test "fallback selection works when LLM fails" do
      entities = [
        %{"name" => "Student A", "type" => "Student", "properties" => "Freshman"},
        %{"name" => "Professor B", "type" => "Professor", "properties" => "CS Dept"},
        %{"name" => "Media C", "type" => "Media", "properties" => "News reporter"}
      ]

      # Mock EntityReader to return these entities
      result = AgentSelector.select_agents("test_sim", "campus", 2)

      # Should return up to max_agents
      assert length(result.selected_agents) <= 2
      assert result.reasoning != ""
    end
  end

  describe "select_agents/4" do
    test "includes simulation requirement in context" do
      entities = [
        %{"name" => "Student A", "type" => "Student", "properties" => "Freshman"}
      ]

      result = AgentSelector.select_agents("test_sim", "topic", 2, "simulation requirement")

      assert is_list(result.selected_agents)
      assert is_binary(result.reasoning)
    end
  end
end
