defmodule Miroex.Simulation.ConfigGenerator do
  @moduledoc """
  Generate OASIS simulation configuration using LLM.

  Enhanced with:
  - Intelligent time configuration (duration, peak/off-peak hours)
  - Activity level configuration per agent type
  - Event injection (initial posts, hot topics)
  - Platform-specific configurations
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
      "off_peak_hours": [0, 1, 2, 3, 4, 5],
      "peak_multiplier": 2.0,
      "off_peak_multiplier": 0.5
    },
    "agent_configs": [
      {
        "agent_id": 0,
        "entity_name": "Entity Name",
        "entity_type": "Type",
        "activity_level": 0.8,
        "active_hours": [18, 19, 20, 21, 22],
        "posts_per_hour": 0.6,
        "likes_per_hour": 3.0,
        "comments_per_hour": 1.5,
        "stance": "supportive",
        "influence_score": 0.7
      }
    ],
    "event_config": {
      "initial_posts": [
        {"content": "Topic 1", "type": "question", "urgency": "high"},
        {"content": "Topic 2", "type": "statement", "urgency": "medium"}
      ],
      "hot_topics": ["Topic 1", "Topic 2"],
      "scheduled_events": [
        {"round": 10, "event": "major_announcement", "description": "..."}
      ],
      "narrative_direction": "Description of the simulation direction",
      "controversy_level": 0.5
    },
    "platform_config": {
      "twitter": {
        "character_limit": 280,
        "trending_threshold": 100,
        "viral_threshold": 1000
      },
      "reddit": {
        "subreddit": "simulation",
        "upvote_threshold": 50,
        "hot_threshold": 500
      }
    }
  }

  Adjust values based on the number of agents and the simulation requirements.
  """

  @doc """
  Generates a complete simulation configuration.

  ## Parameters
    - requirements: The simulation requirements string
    - entities: List of entity maps
    - entity_types: List of entity type strings
    - opts: Optional parameters

  ## Returns
    {:ok, config_map} | {:error, reason}
  """
  @spec generate(String.t(), [map()], [String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def generate(requirements, entities, entity_types, opts \\ []) do
    platform = Keyword.get(opts, :platform, :both)
    agent_count = Keyword.get(opts, :agent_count, length(entities))

    messages = [
      %{role: "system", content: @system_prompt},
      %{
        role: "user",
        content: """
        Generate simulation config:
        Requirements: #{requirements}
        Entity Types: #{Enum.join(entity_types, ", ")}
        Number of Entities: #{agent_count}
        Platform: #{platform}

        Generate a realistic configuration based on these parameters.
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

  @doc """
  Generates time configuration with intelligent defaults.

  ## Parameters
    - duration_hours: Total simulation duration
    - agent_count: Number of agents
    - opts: Options including peak_hours, off_peak_hours

  ## Returns
    time_config map
  """
  @spec generate_time_config(non_neg_integer(), non_neg_integer(), keyword()) :: map()
  def generate_time_config(duration_hours, agent_count, opts \\ []) do
    peak_hours = Keyword.get(opts, :peak_hours, [19, 20, 21, 22])
    off_peak_hours = Keyword.get(opts, :off_peak_hours, [0, 1, 2, 3, 4, 5])

    # Calculate agents per hour based on total count
    base_agents_per_hour = max(5, div(agent_count, div(duration_hours, 4)))

    %{
      total_simulation_hours: duration_hours,
      minutes_per_round: 60,
      agents_per_hour_min: div(base_agents_per_hour, 2),
      agents_per_hour_max: base_agents_per_hour * 2,
      peak_hours: peak_hours,
      off_peak_hours: off_peak_hours,
      peak_multiplier: 2.0,
      off_peak_multiplier: 0.5,
      round_duration_seconds: 5
    }
  end

  @doc """
  Generates activity configuration per agent type.

  ## Parameters
    - entity_type: The type of entity (e.g., "Student", "Professor")
    - base_activity: Base activity level (0.0 - 1.0)
    - opts: Additional options

  ## Returns
    activity_config map
  """
  @spec generate_activity_config(String.t(), float(), keyword()) :: map()
  def generate_activity_config(entity_type, base_activity, opts \\ []) do
    # Different entity types have different activity patterns
    activity_modifiers = %{
      "Student" => 1.2,
      "Professor" => 0.8,
      "Media" => 1.5,
      "Official" => 0.6,
      "Activist" => 1.3,
      "Influencer" => 1.8
    }

    modifier = Map.get(activity_modifiers, entity_type, 1.0)
    adjusted_activity = min(1.0, base_activity * modifier)

    %{
      activity_level: adjusted_activity,
      posts_per_hour: adjusted_activity * 0.5,
      likes_per_hour: adjusted_activity * 3.0,
      comments_per_hour: adjusted_activity * 1.0,
      retweets_per_hour: adjusted_activity * 0.3,
      active_hours: generate_active_hours(entity_type),
      stance: Keyword.get(opts, :stance, "neutral"),
      influence_score: adjusted_activity * 0.8
    }
  end

  @doc """
  Generates event configuration with initial posts and hot topics.

  ## Parameters
    - requirements: The simulation requirements
    - opts: Options including controversy_level, urgency

  ## Returns
    event_config map
  """
  @spec generate_event_config(String.t(), keyword()) :: map()
  def generate_event_config(requirements, opts \\ []) do
    controversy_level = Keyword.get(opts, :controversy_level, 0.5)
    urgency = Keyword.get(opts, :urgency, "medium")

    %{
      initial_posts: generate_initial_posts(requirements, controversy_level, urgency),
      hot_topics: extract_hot_topics(requirements),
      scheduled_events: generate_scheduled_events(requirements),
      narrative_direction: requirements,
      controversy_level: controversy_level,
      urgency: urgency
    }
  end

  @doc """
  Generates platform-specific configuration.

  ## Parameters
    - platform: :twitter | :reddit | :both
    - opts: Platform-specific options

  ## Returns
    platform_config map
  """
  @spec generate_platform_config(atom(), keyword()) :: map()
  def generate_platform_config(:twitter, _opts) do
    %{
      character_limit: 280,
      trending_threshold: 100,
      viral_threshold: 1000,
      hashtag_bonus: 1.5,
      mention_bonus: 2.0,
      image_bonus: 1.3
    }
  end

  def generate_platform_config(:reddit, _opts) do
    %{
      subreddit: "simulation",
      upvote_threshold: 50,
      hot_threshold: 500,
      comment_depth: 3,
      thread_bonus: 1.5,
      long_form_bonus: 1.2
    }
  end

  def generate_platform_config(:both, opts) do
    %{
      twitter: generate_platform_config(:twitter, opts),
      reddit: generate_platform_config(:reddit, opts)
    }
  end

  # Private functions

  defp parse_config(content) do
    content
    |> String.trim()
    |> Jason.decode()
  rescue
    _ ->
      {:error, {:invalid_json, content}}
  end

  defp generate_active_hours(entity_type) do
    # Different types have different active hour patterns
    case entity_type do
      "Student" ->
        [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]

      "Professor" ->
        [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]

      "Media" ->
        [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]

      "Official" ->
        [9, 10, 11, 12, 13, 14, 15, 16, 17]

      "Activist" ->
        [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]

      "Influencer" ->
        [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]

      _ ->
        [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
    end
  end

  defp generate_initial_posts(requirements, controversy_level, urgency) do
    # Generate initial posts based on requirements
    base_posts = [
      %{content: "What's everyone's take on this situation?", type: "question", urgency: urgency},
      %{content: "Just heard about the latest developments", type: "statement", urgency: urgency}
    ]

    # Add controversial posts if level is high
    if controversy_level > 0.7 do
      [
        %{content: "This is completely unacceptable!", type: "opinion", urgency: "high"},
        %{
          content: "I strongly disagree with the current approach",
          type: "opinion",
          urgency: "high"
        }
        | base_posts
      ]
    else
      base_posts
    end
  end

  defp extract_hot_topics(requirements) do
    # Extract key terms from requirements as hot topics
    requirements
    |> String.split(~r/[\s,\.!?;:]+/, trim: true)
    |> Enum.reject(fn word ->
      String.length(word) < 4 or
        word in ["this", "that", "with", "from", "they", "have", "been"]
    end)
    |> Enum.take(5)
    |> Enum.uniq()
  end

  defp generate_scheduled_events(requirements) do
    # Generate a few scheduled events at different rounds
    [
      %{round: 10, event: "announcement", description: "Major update revealed"},
      %{round: 25, event: "debate", description: "Public discussion intensifies"},
      %{round: 50, event: "resolution", description: "Outcome becomes clear"}
    ]
  end
end
