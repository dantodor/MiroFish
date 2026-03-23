defmodule Miroex.Simulation.OrchestratorTest do
  use ExUnit.Case, async: false

  alias Miroex.Simulation.Orchestrator

  describe "init/1" do
    test "initializes with correct state" do
      {:ok, pid} =
        Orchestrator.start_link(
          simulation_id: "test_sim_2",
          project_id: "test_proj_2",
          user_id: 1
        )

      state = Orchestrator.get_status(pid)
      assert state.simulation_id == "test_sim_2"
      assert state.status == :initialized
      assert state.current_round == 0
    end
  end

  describe "get_status/1" do
    test "returns current orchestrator state" do
      {:ok, pid} =
        Orchestrator.start_link(
          simulation_id: "test_sim",
          project_id: "test_proj",
          user_id: 1
        )

      status = Orchestrator.get_status(pid)
      assert is_map(status)
      assert status.simulation_id == "test_sim"
    end
  end
end
