defmodule MiroexWeb.SimulationController do
  use MiroexWeb, :controller

  alias Miroex.Simulation
  alias Miroex.Simulation.{Orchestrator, BatchInterview}

  @doc """
  Interview a single agent.

  POST /api/simulation/:id/interview

  Request body:
    - agent_id: integer
    - question: string

  Response:
    - ok: boolean
    - response: string (if ok)
    - error: string (if not ok)
  """
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

  @doc """
  Batch interview multiple agents.

  POST /api/simulation/:id/interview/batch

  Request body:
    - interviews: list of %{agent_id: integer, prompt: string}
    - platform: "twitter" | "reddit" | "both" | nil (nil means both)

  Response:
    - success: boolean
    - interviews_count: integer
    - results: list of %{agent_id, agent_name, platform, response}
  """
  def batch_interview(conn, %{
        "id" => simulation_id,
        "interviews" => interviews,
        "platform" => platform
      }) do
    simulation = Simulation.get_simulation(simulation_id)

    if simulation do
      interviews_parsed =
        Enum.map(interviews, fn interview ->
          %{
            agent_id: Map.get(interview, "agent_id") || Map.get(interview, :agent_id),
            prompt: Map.get(interview, "prompt") || Map.get(interview, :prompt)
          }
        end)

      platform_atom = parse_platform(platform)

      case BatchInterview.batch_interview(simulation_id, interviews_parsed, platform_atom) do
        {:ok, %{interviews_count: count, results: results}} ->
          json(conn, %{
            success: true,
            interviews_count: count,
            results: results
          })

        {:error, reason} ->
          json(conn, %{
            success: false,
            error: reason
          })
      end
    else
      json(conn, %{success: false, error: "Simulation not found"})
    end
  end

  def batch_interview(conn, %{"id" => simulation_id, "interviews" => interviews}) do
    # No platform specified - default to both
    batch_interview(conn, %{"id" => simulation_id, "interviews" => interviews, "platform" => nil})
  end

  defp parse_platform(nil), do: nil
  defp parse_platform("twitter"), do: :twitter
  defp parse_platform("reddit"), do: :reddit
  defp parse_platform("both"), do: :both
  defp parse_platform(:twitter), do: :twitter
  defp parse_platform(:reddit), do: :reddit
  defp parse_platform(:both), do: :both
  defp parse_platform(_), do: nil
end
