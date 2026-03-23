defmodule Miroex.Simulation.ConfigGenerator do
  @moduledoc """
  Generate OASIS simulation configuration using LLM.
  """
  alias Miroex.AI.Openrouter

  @system_prompt """
  You are a simulation configuration expert. Generate a detailed OASIS simulation configuration
  based on the simulation requirements and entity types provided.

  Return JSON with this structure:
  {
    "time_config": {
      "total_simulation_hours": 72,
      "minutes_per_round": 60,
      "agents_per_hour_min": 5,
      "agents_per_hour_max": 20,
      "peak_hours": [19, 20, 21, 22],
      "off_peak_hours": [0, 1, 2, 3, 4, 5]
    },
    "agent_configs": [
      {
        "agent_id": 0,
        "entity_name": "Entity Name",
        "activity_level": 0.8,
        "active_hours": [18, 19, 20, 21, 22],
        "posts_per_hour": 0.6,
        "stance": "supportive"
      }
    ],
    "event_config": {
      "initial_posts": ["Topic 1", "Topic 2"],
      "hot_topics": ["Topic 1", "Topic 2"],
      "narrative_direction": "Description of the simulation direction"
    }
  }

  Adjust values based on the number of agents and the simulation requirements.
  """

  @spec generate(String.t(), [map()], [String.t()]) :: {:ok, map()} | {:error, term()}
  def generate(requirements, entities, entity_types) when is_list(entities) do
    messages = [
      %{role: "system", content: @system_prompt},
      %{
        role: "user",
        content: """
        Generate simulation config:
        Requirements: #{requirements}
        Entity Types: #{Enum.join(entity_types, ", ")}
        Number of Entities: #{length(entities)}
        """
      }
    ]

    case Openrouter.chat(messages) do
      {:ok, %{content: content}} ->
        parse_config(content)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_config(content) do
    content
    |> String.trim()
    |> Jason.decode()
  rescue
    _ ->
      {:error, {:invalid_json, content}}
  end
end
