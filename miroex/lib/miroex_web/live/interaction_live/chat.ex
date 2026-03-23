defmodule MiroexWeb.InteractionLive.Chat do
  use MiroexWeb, :live_view

  @impl true
  def mount(%{"report_id" => report_id}, _session, socket) do
    {:ok, assign(socket, report_id: report_id, messages: [], input: "")}
  end

  @impl true
  def handle_event("send", %{"message" => message}, socket) do
    messages = socket.assigns.messages ++ [%{role: "user", content: message}]
    {:noreply, assign(socket, messages: messages, input: "")}
  end

  @impl true
  def handle_event("form_change", %{"message" => message}, socket) do
    {:noreply, assign(socket, input: message)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 max-w-4xl mx-auto">
      <.link navigate={~p"/projects"} class="text-orange-500 hover:underline mb-4 block">
        &larr; Back to Projects
      </.link>

      <div class="bg-white rounded-lg border p-6">
        <h1 class="text-2xl font-bold mb-4">Chat with Agents</h1>

        <div class="h-96 overflow-y-auto border rounded p-4 mb-4">
          <%= for msg <- @messages do %>
            <div class={["mb-2", if(msg.role == "user", do: "text-right", else: "text-left")]}>
              <span class={[
                "inline-block px-3 py-1 rounded",
                if(msg.role == "user", do: "bg-orange-100", else: "bg-gray-100")
              ]}>
                {msg.content}
              </span>
            </div>
          <% end %>
        </div>

        <.form for={%{}} phx-submit="send" class="flex gap-2">
          <input
            type="text"
            name="message"
            value={@input}
            phx-keydown="enter"
            class="flex-1 border rounded px-3 py-2"
            placeholder="Ask about the simulation..."
          />
          <button type="submit" class="bg-orange-500 text-white px-4 py-2 rounded-lg">Send</button>
        </.form>
      </div>
    </div>
    """
  end
end
