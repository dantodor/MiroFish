defmodule MiroexWeb.InterviewLive.InterviewComponents do
  use MiroexWeb, :html

  def interview_config_form(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <h1 class="text-3xl font-bold mb-6">Configure Interview</h1>

      <div class="bg-white shadow rounded-lg p-6 mb-6">
        <.form for={%{}} phx-change="update_topic" phx-submit="start_interview" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Interview Topic</label>
            <textarea
              name="topic"
              value={@interview_topic}
              placeholder="e.g., 'Views on the new campus policy'"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              rows="3"
            ></textarea>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Platform</label>
              <select
                name="platform"
                phx-change="update_platform"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              >
                <option value="both" selected={@platform == :both}>Both Twitter & Reddit</option>
                <option value="twitter" selected={@platform == :twitter}>Twitter Only</option>
                <option value="reddit" selected={@platform == :reddit}>Reddit Only</option>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Max Agents</label>
              <input
                type="number"
                name="max_agents"
                value={@max_agents}
                min="1"
                max="10"
                phx-change="update_max_agents"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              />
            </div>
          </div>

          <div class="flex items-center space-x-4 pt-4">
            <label class="flex items-center">
              <input
                type="checkbox"
                name="auto_select"
                checked={@auto_select}
                phx-click="toggle_auto_select"
                phx-value-auto_select={if @auto_select, do: "false", else: "true"}
                class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
              />
              <span class="ml-2 text-sm text-gray-700">Auto-select relevant agents</span>
            </label>

            <%= if @auto_select && @interview_topic != "" do %>
              <button
                type="button"
                phx-click="auto_select_agents"
                class="text-sm text-indigo-600 hover:text-indigo-800"
              >
                Select Agents Now
              </button>
            <% end %>
          </div>
        </.form>
      </div>

      <div class="bg-white shadow rounded-lg p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-semibold">Select Agents ({length(@selected_agents)} selected)</h2>
          <div class="space-x-2">
            <button
              phx-click="select_all"
              class="text-sm text-indigo-600 hover:text-indigo-800"
            >
              Select All
            </button>
            <button
              phx-click="clear_selection"
              class="text-sm text-gray-600 hover:text-gray-800"
            >
              Clear
            </button>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <%= for agent <- @agents do %>
            <div
              phx-click="toggle_agent"
              phx-value-agent_id={agent.agent_id}
              class={[
                "border rounded-lg p-4 cursor-pointer transition-colors",
                if(agent.agent_id in @selected_agents,
                  do: "border-indigo-500 bg-indigo-50",
                  else: "border-gray-200 hover:border-indigo-300"
                )
              ]}
            >
              <div class="flex items-start justify-between">
                <div>
                  <h3 class="font-medium text-gray-900">{agent.name}</h3>
                  <span class="text-xs text-gray-500">{agent.type}</span>
                </div>
                <input
                  type="checkbox"
                  checked={agent.agent_id in @selected_agents}
                  class="rounded border-gray-300 text-indigo-600"
                  phx-click={JS.push("toggle_agent", value: %{agent_id: agent.agent_id})}
                />
              </div>
              <%= if agent.bio != "" do %>
                <p class="mt-2 text-sm text-gray-600 line-clamp-3">{agent.bio}</p>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <%= if @error do %>
        <div class="mt-4 p-4 bg-red-50 border border-red-200 rounded-md">
          <p class="text-red-700">{@error}</p>
        </div>
      <% end %>

      <div class="mt-6 flex justify-end">
        <button
          phx-click="start_interview"
          disabled={@interview_topic == "" || @selected_agents == []}
          class="bg-indigo-600 text-white px-6 py-2 rounded-md font-medium hover:bg-indigo-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
        >
          Start Interview
        </button>
      </div>
    </div>
    """
  end

  def interview_results(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto p-6">
      <h1 class="text-3xl font-bold mb-2">Interview Results</h1>
      <p class="text-gray-600 mb-6">Topic: {@interview_topic}</p>

      <%= if @loading do %>
        <div class="text-center py-12">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
          <p class="text-gray-600">Conducting interviews... {@progress}%</p>
        </div>
      <% else %>
        <%= if @error do %>
          <div class="p-4 bg-red-50 border border-red-200 rounded-md">
            <p class="text-red-700">{@error}</p>
          </div>
        <% else %>
          <div class="space-y-8">
            <%= if @questions != [] do %>
              <div class="bg-white shadow rounded-lg p-6">
                <h2 class="text-xl font-semibold mb-4">Interview Questions</h2>
                <ol class="list-decimal list-inside space-y-2">
                  <%= for question <- @questions do %>
                    <li class="text-gray-700">{question}</li>
                  <% end %>
                </ol>
              </div>
            <% end %>

            <div class="space-y-6">
              <%= for result <- @results do %>
                <.agent_result_card result={result} />
              <% end %>
            </div>

            <div class="flex justify-between pt-6 border-t">
              <button
                phx-click="export_results"
                class="text-indigo-600 hover:text-indigo-800"
              >
                Export Results
              </button>
              <a
                href={~p"/projects/#{@project.id}/simulation/#{@simulation.id}"}
                class="bg-gray-600 text-white px-6 py-2 rounded-md font-medium hover:bg-gray-700"
              >
                Back to Simulation
              </a>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def agent_result_card(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h3 class="text-xl font-semibold text-gray-900">{@result.agent_name}</h3>
          <span class="text-sm text-gray-500">Agent #{@result.agent_id}</span>
        </div>
        <div class="flex space-x-2">
          <%= for platform <- Enum.map(@result.platforms, & &1.platform) |> Enum.uniq() do %>
            <span class={platform_badge_class(platform)}>
              {platform_name(platform)}
            </span>
          <% end %>
        </div>
      </div>

      <div class="space-y-4">
        <%= for platform_result <- @result.platforms do %>
          <div class="border-l-4 border-indigo-200 pl-4">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-gray-700">{platform_name(platform_result.platform)}</span>
            </div>
            <div class="prose prose-sm max-w-none">
              <%= for paragraph <- String.split(platform_result.response, "\n\n") do %>
                <p class="text-gray-700 mb-2">{paragraph}</p>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp platform_badge_class(:twitter),
    do: "px-2 py-1 bg-blue-100 text-blue-800 rounded text-xs font-medium"

  defp platform_badge_class(:reddit),
    do: "px-2 py-1 bg-orange-100 text-orange-800 rounded text-xs font-medium"

  defp platform_badge_class(_),
    do: "px-2 py-1 bg-gray-100 text-gray-800 rounded text-xs font-medium"

  defp platform_name(:twitter), do: "Twitter"
  defp platform_name(:reddit), do: "Reddit"
  defp platform_name(_), do: "Unknown"
end
