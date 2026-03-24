defmodule Miroex.Simulation.CrossPlatformCoordinatorTest do
  use ExUnit.Case, async: false

  alias Miroex.Simulation.CrossPlatformCoordinator

  setup do
    # Start the AgentRegistry if not already running
    unless Process.whereis(Miroex.Simulation.AgentRegistry) do
      {:ok, _} = Registry.start_link(keys: :unique, name: Miroex.Simulation.AgentRegistry)
    end

    :ok
  end

  describe "start_link/1" do
    test "starts with simulation_id" do
      opts = [simulation_id: "test_sim_#{System.unique_integer([:positive])}"]
      assert {:ok, pid} = CrossPlatformCoordinator.start_link(opts)
      assert is_pid(pid)
      GenServer.stop(pid)
    end
  end

  describe "register_agent/4" do
    setup do
      sim_id = "test_sim_#{System.unique_integer([:positive])}"
      {:ok, pid} = CrossPlatformCoordinator.start_link(simulation_id: sim_id)
      on_exit(fn -> GenServer.stop(pid) end)
      %{pid: pid, sim_id: sim_id}
    end

    test "registers agent on platform", %{pid: pid} do
      :ok = CrossPlatformCoordinator.register_agent(pid, 1, "Alice", :twitter)

      platforms = CrossPlatformCoordinator.get_agent_platforms(pid)
      assert length(platforms) == 1
      assert hd(platforms).name == "Alice"
      assert :twitter in hd(platforms).platforms
    end

    test "registers same agent on multiple platforms", %{pid: pid} do
      :ok = CrossPlatformCoordinator.register_agent(pid, 1, "Alice", :twitter)
      :ok = CrossPlatformCoordinator.register_agent(pid, 1, "Alice", :reddit)

      platforms = CrossPlatformCoordinator.get_agent_platforms(pid)
      assert length(platforms) == 1
      agent = hd(platforms)
      assert :twitter in agent.platforms
      assert :reddit in agent.platforms
    end
  end

  describe "record_interaction/2" do
    setup do
      sim_id = "test_sim_#{System.unique_integer([:positive])}"
      {:ok, pid} = CrossPlatformCoordinator.start_link(simulation_id: sim_id)
      on_exit(fn -> GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "records cross-platform interaction", %{pid: pid} do
      interaction = %{
        type: :mention,
        from_platform: :twitter,
        to_platform: :reddit,
        source_agent: 1,
        target_agent: 2,
        content: "Hey check this out"
      }

      :ok = CrossPlatformCoordinator.record_interaction(pid, interaction)

      stats = CrossPlatformCoordinator.get_cross_platform_stats(pid)
      assert stats.total_interactions == 1
      assert stats.twitter_to_reddit == 1
    end
  end

  describe "get_cross_platform_stats/1" do
    setup do
      sim_id = "test_sim_#{System.unique_integer([:positive])}"
      {:ok, pid} = CrossPlatformCoordinator.start_link(simulation_id: sim_id)
      on_exit(fn -> GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "returns zero stats initially", %{pid: pid} do
      stats = CrossPlatformCoordinator.get_cross_platform_stats(pid)
      assert stats.total_interactions == 0
      assert stats.twitter_to_reddit == 0
      assert stats.reddit_to_twitter == 0
    end
  end

  describe "can_see_platform?/3" do
    setup do
      sim_id = "test_sim_#{System.unique_integer([:positive])}"
      {:ok, pid} = CrossPlatformCoordinator.start_link(simulation_id: sim_id)
      on_exit(fn -> GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "agent can see platform they're on", %{pid: pid} do
      :ok = CrossPlatformCoordinator.register_agent(pid, 1, "Alice", :twitter)

      assert CrossPlatformCoordinator.can_see_platform?(pid, 1, :twitter)
      refute CrossPlatformCoordinator.can_see_platform?(pid, 1, :reddit)
    end
  end
end
