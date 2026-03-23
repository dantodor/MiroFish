defmodule MiroexWeb.ProjectLive.Step4Report do
  use MiroexWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border p-6">
      <h2 class="text-xl font-bold mb-4">Step 4: Report Generation</h2>

      <p class="text-gray-500 mb-4">
        Generate a comprehensive report analyzing the simulation results.
      </p>

      <.link
        navigate={~p"/reports/new?project_id=#{@project.id}"}
        class="bg-orange-500 text-white px-4 py-2 rounded-lg inline-block"
      >
        Generate Report
      </.link>
    </div>
    """
  end
end
