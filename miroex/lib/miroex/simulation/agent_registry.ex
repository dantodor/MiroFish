defmodule Miroex.Simulation.AgentRegistry do
  @moduledoc """
  Registry for looking up agent GenServers by simulation and agent_id.
  """
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    table = :ets.new(__MODULE__, [:named_table, read_concurrency: true])
    {:ok, %{table: table}}
  end

  def register(simulation_id, agent_id, agent_pid) do
    key = {simulation_id, agent_id}
    :ets.insert(__MODULE__, {key, agent_pid})
  end

  def unregister(simulation_id, agent_id) do
    key = {simulation_id, agent_id}
    :ets.delete(__MODULE__, key)
  end

  def lookup(simulation_id, agent_id) do
    key = {simulation_id, agent_id}

    case :ets.lookup(__MODULE__, key) do
      [{^key, pid}] -> {:ok, pid}
      [] -> :error
    end
  end

  def agents_by_simulation(simulation_id) do
    pattern = {{simulation_id, :_}, :_}

    :ets.match_object(__MODULE__, pattern)
    |> Enum.map(fn {_, pid} -> pid end)
  end

  def clear_simulation(simulation_id) do
    pattern = {{simulation_id, :_}, :_}
    :ets.match_delete(__MODULE__, pattern)
  end
end
