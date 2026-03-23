defmodule MiroexWeb.SimulationController do
  use MiroexWeb, :controller

  alias Miroex.Simulation
  alias Miroex.Simulation.Orchestrator

  def interview_agent(conn, %{
        "id" => simulation_id,
        "agent_id" => agent_id,
        "question" => question
      }) do
    simulation = Simulation.get_simulation(simulation_id)

    if simulation do
      orch_name = String.to_atom("orchestrator_#{simulation_id}")

      case Orchestrator.interview_agent(orch_name, agent_id, question) do
        {:ok, response} ->
          Simulation.create_interview(
            %{
              simulation_id: simulation_id,
              agent_id: agent_id,
              question: question,
              response: response
            },
            simulation.user_id
          )

          json(conn, %{ok: true, response: response})

        {:error, reason} ->
          json(conn, %{ok: false, error: Atom.to_string(reason)})
      end
    else
      json(conn, %{ok: false, error: "Simulation not found"})
    end
  end
end
