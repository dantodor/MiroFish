defmodule Miroex.Simulation.AgentRegistryTest do
  use ExUnit.Case, async: false

  alias Miroex.Simulation.AgentRegistry

  setup do
    case AgentRegistry.start_link([]) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    :ok
  end

  describe "register/3" do
    @tag :skip
    test "registers an agent" do
      :ok = AgentRegistry.register("sim1", 1, self())
      assert AgentRegistry.lookup("sim1", 1) == {:ok, self()}
    end
  end

  describe "lookup/2" do
    test "returns error for non-existent agent" do
      result = AgentRegistry.lookup("nonexistent", 1)
      assert result == :error
    end
  end

  describe "unregister/2" do
    @tag :skip
    test "unregisters an agent" do
      :ok = AgentRegistry.register("sim1", 1, self())
      :ok = AgentRegistry.unregister("sim1", 1)
      assert AgentRegistry.lookup("sim1", 1) == :error
    end
  end

  describe "agents_by_simulation/1" do
    @tag :skip
    test "returns all agents for a simulation" do
      :ok = AgentRegistry.register("sim1", 1, self())
      :ok = AgentRegistry.register("sim1", 2, spawn(fn -> :ok end))
      :ok = AgentRegistry.register("sim2", 1, spawn(fn -> :ok end))

      sim1_agents = AgentRegistry.agents_by_simulation("sim1")
      assert length(sim1_agents) == 2
    end
  end

  describe "clear_simulation/1" do
    @tag :skip
    test "removes all agents for a simulation" do
      :ok = AgentRegistry.register("sim1", 1, self())
      :ok = AgentRegistry.register("sim1", 2, spawn(fn -> :ok end))
      :ok = AgentRegistry.register("sim2", 1, spawn(fn -> :ok end))

      AgentRegistry.clear_simulation("sim1")

      assert AgentRegistry.agents_by_simulation("sim1") == []
      assert length(AgentRegistry.agents_by_simulation("sim2")) == 1
    end
  end
end
