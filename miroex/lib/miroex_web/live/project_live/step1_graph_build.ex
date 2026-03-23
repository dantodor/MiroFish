defmodule MiroexWeb.ProjectLive.Step1GraphBuild do
  use MiroexWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, uploading: false, error: nil, progress: 0, message: nil)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("upload", %{"file" => %{"filename" => filename}}, socket) do
    if uploading?(filename) do
      {:noreply, assign(socket, error: "Invalid file type")}
    else
      {:noreply, assign(socket, uploading: true, progress: 0, message: "File uploaded")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border p-6">
      <h2 class="text-xl font-bold mb-4">Step 1: Graph Build</h2>

      <.form for={%{}} phx-submit="upload" phx-target={@myself}>
        <input type="file" name="file[filename]" accept=".pdf,.md,.txt" class="mb-4" />
        <button
          type="submit"
          class="bg-orange-500 text-white px-4 py-2 rounded-lg"
          disabled={@uploading}
        >
          {if @uploading, do: "Processing...", else: "Upload & Build Graph"}
        </button>
      </.form>

      <%= if @uploading do %>
        <div class="mt-4">
          <div class="w-full bg-gray-200 rounded-full h-2">
            <div class="bg-orange-500 h-2 rounded-full transition-all" style={"width: #{@progress}%"}>
            </div>
          </div>
          <p class="text-sm text-gray-500 mt-2">{@message || "Processing..."} {@progress}%</p>
        </div>
      <% end %>

      <%= if @error do %>
        <p class="mt-4 text-red-500">{@error}</p>
      <% end %>
    </div>
    """
  end

  defp uploading?(filename) do
    ext = Path.extname(filename) |> String.downcase()
    ext not in [".pdf", ".md", ".txt"]
  end
end
