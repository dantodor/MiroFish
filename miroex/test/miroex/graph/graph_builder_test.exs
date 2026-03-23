defmodule Miroex.Graph.GraphBuilderTest do
  use ExUnit.Case, async: true

  alias Miroex.Graph.GraphBuilder

  describe "build/3" do
    test "handles invalid graph gracefully" do
      ontology = %{entity_types: ["Person"], edge_types: ["knows"]}
      chunks = ["This is a test chunk."]

      result = GraphBuilder.build("invalid_graph_id", ontology, chunks)
      assert match?({:error, _}, result)
    end
  end
end
