defmodule Miroex.Simulation.StateManagerTest do
  use ExUnit.Case, async: false

  alias Miroex.Simulation.StateManager

  @temp_dir "/tmp/miroex_test_state"

  setup do
    File.mkdir_p!(@temp_dir)
    Application.put_env(:miroex, :simulation_state_dir, @temp_dir)
    on_exit(fn -> cleanup_temp_dir() end)
    :ok
  end

  defp cleanup_temp_dir do
    File.rm_rf(@temp_dir)
  end

  describe "save_orchestrator_state/1 and load_orchestrator_state/1" do
    test "saves and loads orchestrator state" do
      state = %{
        simulation_id: "test_sim_1",
        project_id: "proj_1",
        user_id: 1,
        current_round: 10,
        total_rounds: 72,
        status: :running,
        config: %{enable_twitter: true},
        twitter_env_pid: nil,
        reddit_env_pid: nil,
        agent_pids: [],
        memory_updater_pid: nil
      }

      assert :ok = StateManager.save_orchestrator_state(state)

      assert StateManager.state_exists?("test_sim_1")

      {:ok, loaded} = StateManager.load_orchestrator_state("test_sim_1")

      assert loaded.simulation_id == "test_sim_1"
      assert loaded.project_id == "proj_1"
      assert loaded.user_id == 1
      assert loaded.current_round == 10
      assert loaded.total_rounds == 72
      assert loaded.status == :running
      assert loaded.config == %{enable_twitter: true}
    end
  end

  describe "state_exists?/1" do
    test "returns false for non-existent state" do
      refute StateManager.state_exists?("non_existent_sim")
    end

    test "returns true for saved state" do
      state = %{
        simulation_id: "exists_sim",
        project_id: "proj_1",
        user_id: 1,
        current_round: 1,
        total_rounds: 10,
        status: :initialized,
        config: %{},
        twitter_env_pid: nil,
        reddit_env_pid: nil,
        agent_pids: [],
        memory_updater_pid: nil
      }

      StateManager.save_orchestrator_state(state)
      assert StateManager.state_exists?("exists_sim")
    end
  end

  describe "delete_simulation_state/2" do
    test "deletes saved state" do
      state = %{
        simulation_id: "delete_sim",
        project_id: "proj_1",
        user_id: 1,
        current_round: 5,
        total_rounds: 10,
        status: :running,
        config: %{},
        twitter_env_pid: nil,
        reddit_env_pid: nil,
        agent_pids: [],
        memory_updater_pid: nil
      }

      StateManager.save_orchestrator_state(state)
      assert StateManager.state_exists?("delete_sim")

      StateManager.delete_simulation_state("delete_sim", self())
      refute StateManager.state_exists?("delete_sim")
    end
  end

  describe "list_saved_states/0" do
    test "returns list of saved simulation IDs" do
      state1 = sim_state("list_sim_1")
      state2 = sim_state("list_sim_2")
      state3 = sim_state("list_sim_3")

      StateManager.save_orchestrator_state(state1)
      StateManager.save_orchestrator_state(state2)
      StateManager.save_orchestrator_state(state3)

      saved = StateManager.list_saved_states()
      assert "list_sim_1" in saved
      assert "list_sim_2" in saved
      assert "list_sim_3" in saved
    end

    test "returns empty list when no states saved" do
      cleanup_temp_dir()
      File.mkdir_p!(@temp_dir)

      saved = StateManager.list_saved_states()
      assert saved == []
    end
  end

  defp sim_state(id) do
    %{
      simulation_id: id,
      project_id: "proj_1",
      user_id: 1,
      current_round: 1,
      total_rounds: 10,
      status: :initialized,
      config: %{},
      twitter_env_pid: nil,
      reddit_env_pid: nil,
      agent_pids: [],
      memory_updater_pid: nil
    }
  end
end
