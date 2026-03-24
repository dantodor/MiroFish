defmodule Miroex.Simulation.ParallelRunnerTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.ParallelRunner

  describe "start_link/1" do
    test "starts with valid options" do
      opts = [
        simulation_id: "test_sim_#{System.unique_integer([:positive])}",
        graph_id: "test_graph",
        config: %{rounds: 10}
      ]

      assert {:ok, pid} = ParallelRunner.start_link(opts)
      assert is_pid(pid)
    end

    test "requires simulation_id" do
      opts = [
        graph_id: "test_graph",
        config: %{}
      ]

      assert_raise KeyError, fn ->
        ParallelRunner.start_link(opts)
      end
    end
  end

  describe "via_tuple/1" do
    test "creates proper via tuple" do
      # Test the private function indirectly through start_link
      sim_id = "test_sim_via"

      opts = [
        simulation_id: sim_id,
        graph_id: "test_graph",
        config: %{}
      ]

      {:ok, pid} = ParallelRunner.start_link(opts)
      assert is_pid(pid)
    end
  end
end
