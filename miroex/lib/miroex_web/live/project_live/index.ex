defmodule MiroexWeb.ProjectLive.Index do
  use MiroexWeb, :live_view
  alias Miroex.Simulation

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :projects, [])}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    user = socket.assigns.current_user
    {:noreply, assign(socket, :projects, Simulation.list_projects(user.id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 max-w-6xl mx-auto">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-2xl font-bold">Projects</h1>
        <.link
          navigate={~p"/projects/new"}
          class="bg-orange-500 text-white px-4 py-2 rounded-lg hover:bg-orange-600"
        >
          New Project
        </.link>
      </div>

      <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <%= for project <- @projects do %>
          <.link
            navigate={~p"/projects/#{project.id}"}
            class="block p-6 bg-white rounded-lg border hover:border-orange-500 transition"
          >
            <h2 class="text-lg font-semibold mb-2">{project.name}</h2>
            <p class="text-sm text-gray-500 mb-2">Status: {project.status}</p>
            <p class="text-xs text-gray-400">{project.inserted_at}</p>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end
end
