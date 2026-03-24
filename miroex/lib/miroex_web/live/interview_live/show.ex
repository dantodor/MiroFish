defmodule MiroexWeb.InterviewLive.Show do
  use MiroexWeb, :live_view

  alias Miroex.Simulation
  alias Miroex.Simulation.BatchInterview

  @impl true
  def mount(%{"project_id" => project_id, "simulation_id" => simulation_id}, _session, socket) do
    project = Simulation.get_project(project_id)
    simulation = Simulation.get_simulation(simulation_id)

    if project && simulation do
      {:ok,
       socket
       |> assign(:project, project)
       |> assign(:simulation, simulation)
       |> assign(:loading, true)
       |> assign(:error, nil)
       |> assign(:results, [])
       |> assign(:selection_reasoning, "")
       |> assign(:questions, [])
       |> assign(:progress, 0)
       |> assign(:interview_topic, "")
       |> assign(:platform, :both)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Simulation not found")
       |> push_navigate(to: ~p"/projects/#{project_id}")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    interview_topic = params["topic"] || ""
    selected_agents = parse_agent_ids(params["agents"])
    platform = parse_platform(params["platform"])
    max_agents = String.to_integer(params["max_agents"] || "5")

    socket =
      socket
      |> assign(:interview_topic, interview_topic)
      |> assign(:platform, platform)
      |> assign(:max_agents, max_agents)

    if connected?(socket) and selected_agents != [] do
      # Start the interview process
      send(self(), {:start_interview, interview_topic, selected_agents, platform, max_agents})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:start_interview, topic, agent_ids, platform, _max_agents}, socket) do
    # Generate questions
    simulation_requirement = socket.assigns.simulation.simulation_requirement

    questions =
      BatchInterview.generate_interview_questions(topic, simulation_requirement, 3)

    combined_prompt = BatchInterview.format_interview_prompt(questions)

    interview_requests =
      Enum.map(agent_ids, fn agent_id ->
        %{
          agent_id: agent_id,
          prompt: combined_prompt
        }
      end)

    # Start async batch interview
    Task.async(fn ->
      BatchInterview.batch_interview(
        socket.assigns.simulation.id,
        interview_requests,
        platform,
        180_000
      )
    end)

    {:noreply,
     socket
     |> assign(:questions, questions)
     |> assign(:loading, true)
     |> assign(:progress, 10)}
  end

  def handle_info({ref, {:ok, %{results: results}}}, socket)
      when is_reference(ref) do
    # Group results by agent for display
    grouped =
      results
      |> Enum.group_by(& &1.agent_id)
      |> Enum.map(fn {agent_id, agent_results} ->
        # Find the agent name
        primary = List.first(agent_results)

        %{
          agent_id: agent_id,
          agent_name: primary.agent_name,
          platforms: agent_results
        }
      end)

    {:noreply,
     socket
     |> assign(:results, grouped)
     |> assign(:loading, false)
     |> assign(:progress, 100)}
  end

  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref) do
    {:noreply,
     socket
     |> assign(:error, "Interview failed: #{reason}")
     |> assign(:loading, false)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, socket) when is_reference(ref) do
    # Task completed
    {:noreply, socket}
  end

  def handle_info({:update_progress, progress}, socket) do
    {:noreply, assign(socket, :progress, progress)}
  end

  defp parse_agent_ids(nil), do: []

  defp parse_agent_ids(agents_str) do
    agents_str
    |> String.split(",")
    |> Enum.map(&String.to_integer/1)
  end

  defp parse_platform(nil), do: :both
  defp parse_platform("twitter"), do: :twitter
  defp parse_platform("reddit"), do: :reddit
  defp parse_platform("both"), do: :both
  defp parse_platform(_), do: :both
end
