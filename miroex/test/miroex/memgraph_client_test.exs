defmodule Miroex.Graph.MemgraphClientTest do
  use ExUnit.Case, async: true

  alias Miroex.Memgraph

  describe "query/1" do
    test "handles connection errors gracefully" do
      result = Memgraph.query("MATCH (n) RETURN n")
      assert match?({:error, _}, result)
    end
  end

  describe "transaction/1" do
    test "handles connection errors gracefully" do
      result = Memgraph.transaction([{"MATCH (n) RETURN n", %{}}])
      assert match?({:error, _}, result)
    end
  end

  describe "ping/0" do
    test "returns error when not connected" do
      result = Memgraph.ping()
      assert result != :ok
    end
  end
end
