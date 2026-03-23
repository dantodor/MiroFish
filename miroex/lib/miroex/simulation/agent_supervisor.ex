defmodule Miroex.Simulation.AgentSupervisor do
  @moduledoc """
  DynamicSupervisor for agent GenServers.
  """
  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_agent(opts) do
    spec = {Miroex.Simulation.Agent, opts}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_agent(agent_pid) do
    DynamicSupervisor.terminate_child(__MODULE__, agent_pid)
  end

  def count_agents do
    DynamicSupervisor.count_children(__MODULE__)
  end
end
