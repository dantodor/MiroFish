defmodule Miroex.Reports.OutlinePlannerTest do
  use ExUnit.Case, async: true

  alias Miroex.Reports.OutlinePlanner

  describe "OutlinePlanner struct" do
    test "creates outline with title, summary, and sections" do
      outline = %OutlinePlanner{
        title: "Test Report",
        summary: "A test summary",
        sections: []
      }

      assert outline.title == "Test Report"
      assert outline.summary == "A test summary"
      assert outline.sections == []
    end
  end

  describe "OutlinePlanner.Section" do
    alias Miroex.Reports.OutlinePlanner.Section

    test "creates section with title and description" do
      section = %Section{
        title: "Introduction",
        description: "Opening section"
      }

      assert section.title == "Introduction"
      assert section.description == "Opening section"
    end
  end

  describe "plan/3" do
    test "returns error for non-existent graph (uses fallback)" do
      result = OutlinePlanner.plan("nonexistent_sim", "nonexistent_graph", "test requirement")
      # Should return default outline since the graph doesn't exist
      assert {:ok, outline} = result
      assert outline.title == "Future Prediction Report"
      assert length(outline.sections) == 3
    end

    test "plan returns an OutlinePlanner struct" do
      {:ok, outline} = OutlinePlanner.plan("test_sim", "test_graph", "test")
      assert is_struct(outline, OutlinePlanner)
      assert is_binary(outline.title)
      assert is_binary(outline.summary)
      assert is_list(outline.sections)
    end
  end

  describe "fallback behavior" do
    test "plan returns default outline when LLM calls fail" do
      # When the graph doesn't exist and LLM fails, it should return a default outline
      {:ok, outline} =
        OutlinePlanner.plan("nonexistent_sim", "nonexistent_graph", "Test requirement")

      assert outline.title == "Future Prediction Report"
      assert length(outline.sections) == 3
    end
  end
end
