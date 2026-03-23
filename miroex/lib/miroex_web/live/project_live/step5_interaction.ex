defmodule MiroexWeb.ProjectLive.Step5Interaction do
  use MiroexWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border p-6">
      <h2 class="text-xl font-bold mb-4">Step 5: Deep Interaction</h2>

      <p class="text-gray-500 mb-4">
        Chat with agents and the Report Agent to explore simulation insights.
      </p>

      <.link
        navigate={~p"/interaction/#{@project.id}"}
        class="bg-orange-500 text-white px-4 py-2 rounded-lg inline-block"
      >
        Start Chat
      </.link>
    </div>
    """
  end
end
