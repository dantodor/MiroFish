defmodule MiroexWeb.ProjectLive.Step2EnvSetup do
  use MiroexWeb, :live_component
  alias Miroex.Graph.EntityReader

  @impl true
  def mount(socket) do
    {:ok, assign(socket, entities: [], loading: false)}
  end

  @impl true
  def update(assigns, socket) do
    project = assigns.project

    if project.graph_id && project.status == :graph_completed do
      case EntityReader.get_entities(project.graph_id) do
        {:ok, entities} ->
          {:ok, assign(socket, Map.merge(assigns, %{entities: entities, loading: false}))}

        _ ->
          {:ok, assign(socket, Map.merge(assigns, %{entities: [], loading: false}))}
      end
    else
      {:ok, assign(socket, assigns)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border p-6">
      <h2 class="text-xl font-bold mb-4">Step 2: Environment Setup</h2>

      <%= if @loading do %>
        <p>Loading entities...</p>
      <% else %>
        <p class="mb-4">{length(@entities)} entities found in graph</p>

        <h3 class="font-semibold mb-2">Entities</h3>
        <div class="grid gap-2 max-h-60 overflow-y-auto mb-4">
          <%= for entity <- @entities do %>
            <div class="p-2 bg-gray-50 rounded">
              <span class="font-medium">{entity["name"]}</span>
              <span class="text-gray-500 text-sm ml-2">{entity["type"]}</span>
            </div>
          <% end %>
        </div>

        <.link
          navigate={~p"/projects/#{@project.id}?step=3"}
          class="bg-orange-500 text-white px-4 py-2 rounded-lg inline-block"
        >
          Proceed to Simulation
        </.link>
      <% end %>
    </div>
    """
  end
end
