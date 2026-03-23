defmodule MiroexWeb.ReportLive.Show do
  use MiroexWeb, :live_view
  alias Miroex.Reports

  @impl true
  def mount(%{"report_id" => report_id}, _session, socket) do
    user = socket.assigns.current_user
    report = Reports.get_report!(report_id, user.id)

    {:ok, assign(socket, report: report)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 max-w-6xl mx-auto">
      <.link navigate={~p"/projects"} class="text-orange-500 hover:underline mb-4 block">
        &larr; Back to Projects
      </.link>

      <div class="bg-white rounded-lg border p-6">
        <h1 class="text-2xl font-bold mb-4">{@report.name}</h1>
        <p class="text-gray-500 mb-4">Status: {@report.status}</p>

        <%= if @report.full_report do %>
          <div class="prose max-w-none">
            {@report.full_report}
          </div>
        <% else %>
          <p class="text-gray-400">Report not yet generated.</p>
        <% end %>
      </div>
    </div>
    """
  end
end
