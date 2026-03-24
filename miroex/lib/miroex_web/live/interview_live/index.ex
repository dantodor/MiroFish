defmodule MiroexWeb.InterviewLive.Index do
  use MiroexWeb, :live_view

  alias Miroex.Simulation
  alias Miroex.Simulation.AgentSelector

  @impl true
  def mount(%{"project_id" => project_id, "simulation_id" => simulation_id}, _session, socket) do
    project = Simulation.get_project(project_id)
    simulation = Simulation.get_simulation(simulation_id)

    if project && simulation && simulation.status in [:ready, :running] do
      # Get available agents
      agents = get_available_agents(simulation)

      {:ok,
       socket
       |> assign(:project, project)
       |> assign(:simulation, simulation)
       |> assign(:agents, agents)
       |> assign(:selected_agents, [])
       |> assign(:interview_topic, "")
       |> assign(:platform, :both)
       |> assign(:max_agents, 5)
       |> assign(:custom_questions, "")
       |> assign(:loading, false)
       |> assign(:auto_select, true)
       |> assign(:error, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Simulation not found or not ready")
       |> push_navigate(to: ~p"/projects/#{project_id}")}
    end
  end

  @impl true
  def handle_event("update_topic", %{"topic" => topic}, socket) do
    {:noreply, assign(socket, :interview_topic, topic)}
  end

  def handle_event("update_platform", %{"platform" => platform}, socket) do
    platform_atom =
      case platform do
        "twitter" -> :twitter
        "reddit" -> :reddit
        _ -> :both
      end

    {:noreply, assign(socket, :platform, platform_atom)}
  end

  def handle_event("update_max_agents", %{"max_agents" => max}, socket) do
    max_int = String.to_integer(max)
    {:noreply, assign(socket, :max_agents, max_int)}
  end

  def handle_event("toggle_auto_select", %{"auto_select" => auto}, socket) do
    {:noreply,
     socket
     |> assign(:auto_select, auto == "true")
     |> assign(:selected_agents, [])}
  end

  def handle_event("toggle_agent", %{"agent_id" => agent_id}, socket) do
    agent_id_int = String.to_integer(agent_id)

    selected =
      if agent_id_int in socket.assigns.selected_agents do
        List.delete(socket.assigns.selected_agents, agent_id_int)
      else
        [agent_id_int | socket.assigns.selected_agents]
      end

    {:noreply, assign(socket, :selected_agents, selected)}
  end

  def handle_event("select_all", _, socket) do
    all_ids = Enum.map(socket.assigns.agents, & &1.agent_id)
    {:noreply, assign(socket, :selected_agents, all_ids)}
  end

  def handle_event("clear_selection", _, socket) do
    {:noreply, assign(socket, :selected_agents, [])}
  end

  def handle_event("auto_select_agents", _, socket) do
    %{simulation: simulation, interview_topic: topic, max_agents: max} = socket.assigns

    socket =
      if topic != "" do
        %{selected_agents: selected} = AgentSelector.select_agents(simulation.id, topic, max)
        selected_ids = Enum.map(selected, & &1.agent_id)
        assign(socket, :selected_agents, selected_ids)
      else
        put_flash(socket, :error, "Please enter an interview topic first")
      end

    {:noreply, socket}
  end

  def handle_event("start_interview", _, socket) do
    %{simulation: simulation, interview_topic: topic, selected_agents: selected} = socket.assigns

    if topic == "" or selected == [] do
      {:noreply,
       socket
       |> put_flash(:error, "Please enter a topic and select agents")}
    else
      # Generate questions and navigate to interview show page
      socket =
        push_navigate(
          socket,
          to: ~p"/projects/#{simulation.project_id}/simulation/#{simulation.id}/interview/conduct"
        )

      {:noreply, socket}
    end
  end

  defp get_available_agents(simulation) do
    # Get agents from the graph
    case Miroex.Graph.EntityReader.get_entities(simulation.graph_id) do
      {:ok, entities} ->
        Enum.with_index(entities, 1)
        |> Enum.map(fn {entity, idx} ->
          %{
            agent_id: idx,
            name: entity["name"] || "Unknown",
            type: entity["type"] || "Unknown",
            bio: entity["properties"] || ""
          }
        end)

      _ ->
        []
    end
  end
end
