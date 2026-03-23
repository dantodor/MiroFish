defmodule Miroex.Simulation.Runner do
  @moduledoc """
  Starts and manages simulation orchestration.
  """
  alias Miroex.Simulation.Orchestrator

  def start_simulation(simulation_id, project_id, user_id, graph_id, config) do
    name = String.to_atom("orchestrator_#{simulation_id}")

    case Orchestrator.start_link(%{
           name: name,
           simulation_id: simulation_id,
           project_id: project_id,
           user_id: user_id,
           config: config
         }) do
      {:ok, pid} ->
        {:ok, _orch_pid} = Orchestrator.prepare_simulation(pid, graph_id, true, false)
        Orchestrator.start_simulation(pid)
        {:ok, pid}

      error ->
        error
    end
  end

  def stop_simulation(simulation_id) do
    name = String.to_atom("orchestrator_#{simulation_id}")
    Orchestrator.stop_simulation(name)
  end

  def get_simulation_status(simulation_id) do
    name = String.to_atom("orchestrator_#{simulation_id}")
    Orchestrator.get_status(name)
  end
end
