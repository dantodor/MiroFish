defmodule MiroexWeb.ProjectLive.Show do
  use MiroexWeb, :live_view
  alias Miroex.Simulation

  @impl true
  def mount(%{"project_id" => project_id}, _session, socket) do
    user = socket.assigns.current_user
    project = Simulation.get_project!(project_id, user.id)
    simulations = Simulation.list_simulations_by_project(project_id)

    {:ok, assign(socket, project: project, simulations: simulations, current_step: 1)}
  end

  @impl true
  def handle_params(%{"project_id" => _}, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 max-w-6xl mx-auto">
      <.link navigate={~p"/projects"} class="text-orange-500 hover:underline mb-4 block">
        &larr; Back to Projects
      </.link>

      <div class="bg-white rounded-lg border p-6 mb-6">
        <h1 class="text-2xl font-bold mb-2">{@project.name}</h1>
        <p class="text-gray-500">Status: {@project.status}</p>
      </div>

      <.live_component module={StepIndicator} current_step={@current_step} />

      <div class="mt-6">
        <%= case @current_step do %>
          <% 1 -> %>
            <.live_component module={Step1GraphBuild} project={@project} />
          <% 2 -> %>
            <.live_component module={Step2EnvSetup} project={@project} simulations={@simulations} />
          <% 3 -> %>
            <.live_component module={Step3Simulation} project={@project} simulations={@simulations} />
          <% 4 -> %>
            <.live_component module={Step4Report} project={@project} />
          <% 5 -> %>
            <.live_component module={Step5Interaction} project={@project} />
        <% end %>
      </div>
    </div>
    """
  end
end
