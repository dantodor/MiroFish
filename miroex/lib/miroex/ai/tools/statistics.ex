defmodule Miroex.AI.Tools.Statistics do
  @moduledoc """
  Statistics tool for analyzing simulation actions.
  """
  alias Miroex.Simulation

  def execute(simulation_id) do
    case Simulation.list_actions(simulation_id) do
      actions when is_list(actions) ->
        stats = %{
          total_actions: length(actions),
          by_type: count_by_type(actions),
          by_platform: count_by_platform(actions),
          by_agent: count_by_agent(actions),
          posts: filter_by_type(actions, :create_post),
          likes: filter_by_type(actions, :like_post),
          comments: filter_by_type(actions, :comment_post)
        }

        {:ok, stats}

      error ->
        error
    end
  end

  defp count_by_type(actions) do
    actions
    |> Enum.group_by(& &1.action_type)
    |> Enum.map(fn {type, acts} -> {type, length(acts)} end)
    |> Map.new()
  end

  defp count_by_platform(actions) do
    actions
    |> Enum.group_by(& &1.platform)
    |> Enum.map(fn {platform, acts} -> {platform, length(acts)} end)
    |> Map.new()
  end

  defp count_by_agent(actions) do
    actions
    |> Enum.group_by(& &1.agent_id)
    |> Enum.map(fn {id, acts} -> {id, length(acts)} end)
    |> Map.new()
  end

  defp filter_by_type(actions, type) do
    Enum.filter(actions, &(&1.action_type == type))
  end
end
