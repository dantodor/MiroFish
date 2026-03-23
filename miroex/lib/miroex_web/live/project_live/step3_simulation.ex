defmodule MiroexWeb.ProjectLive.Step3Simulation do
  use MiroexWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, running: false, error: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border p-6">
      <h2 class="text-xl font-bold mb-4">Step 3: Simulation</h2>

      <%= if @running do %>
        <p class="text-green-600">Simulation running...</p>
      <% else %>
        <.link
          navigate={~p"/projects/#{@project.id}/simulation/new"}
          class="bg-orange-500 text-white px-4 py-2 rounded-lg inline-block"
        >
          Start Simulation
        </.link>
      <% end %>

      <%= if @error do %>
        <p class="mt-4 text-red-500">{@error}</p>
      <% end %>
    </div>
    """
  end
end
