defmodule MiroexWeb.SimulationLive.Show do
  use MiroexWeb, :live_view
  alias Miroex.Simulation

  @impl true
  def mount(%{"project_id" => project_id, "simulation_id" => simulation_id}, _session, socket) do
    user = socket.assigns.current_user
    project = Simulation.get_project!(project_id, user.id)
    simulation = Simulation.get_simulation!(simulation_id, user.id)

    {:ok, assign(socket, project: project, simulation: simulation)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 max-w-6xl mx-auto">
      <.link
        navigate={~p"/projects/#{@project.id}"}
        class="text-orange-500 hover:underline mb-4 block"
      >
        &larr; Back to Project
      </.link>

      <div class="bg-white rounded-lg border p-6">
        <h1 class="text-2xl font-bold mb-4">{@simulation.name}</h1>
        <p class="text-gray-500">Status: {@simulation.status}</p>
        <p class="text-gray-500">Round: {@simulation.current_round}/{@simulation.total_rounds}</p>
      </div>
    </div>
    """
  end
end
