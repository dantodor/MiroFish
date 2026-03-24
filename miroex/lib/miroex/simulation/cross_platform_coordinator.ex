defmodule Miroex.Simulation.CrossPlatformCoordinator do
  @moduledoc """
  Coordinates agent interactions across Twitter and Reddit platforms.

  This module handles:
  - Tracking which agents exist on which platforms
  - Detecting when agents mention content from other platforms
  - Enabling limited cross-platform visibility (e.g., agents seeing screenshots)
  - Aggregating cross-platform statistics
  """

  use GenServer

  @type agent_platform :: %{
          agent_id: integer(),
          name: String.t(),
          platforms: [:twitter | :reddit]
        }

  @type cross_platform_event :: %{
          type: :mention | :screenshot | :reference,
          from_platform: :twitter | :reddit,
          to_platform: :twitter | :reddit,
          source_agent: integer(),
          target_agent: integer() | nil,
          content: String.t(),
          timestamp: DateTime.t()
        }

  # Client API

  @doc """
  Starts the cross-platform coordinator.

  ## Options
    - :simulation_id - Required. The simulation ID
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    simulation_id = Keyword.fetch!(opts, :simulation_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(simulation_id))
  end

  @doc """
  Registers an agent on a specific platform.
  """
  @spec register_agent(pid(), integer(), String.t(), :twitter | :reddit) :: :ok
  def register_agent(pid, agent_id, name, platform) do
    GenServer.cast(pid, {:register_agent, agent_id, name, platform})
  end

  @doc """
  Records a cross-platform interaction.
  """
  @spec record_interaction(pid(), map()) :: :ok
  def record_interaction(pid, interaction) do
    GenServer.cast(pid, {:record_interaction, interaction})
  end

  @doc """
  Gets all agents and their platform memberships.
  """
  @spec get_agent_platforms(pid()) :: [agent_platform()]
  def get_agent_platforms(pid) do
    GenServer.call(pid, :get_agent_platforms)
  end

  @doc """
  Gets cross-platform interaction statistics.
  """
  @spec get_cross_platform_stats(pid()) :: map()
  def get_cross_platform_stats(pid) do
    GenServer.call(pid, :get_stats)
  end

  @doc """
  Checks if an agent has visibility to another platform's content.
  """
  @spec can_see_platform?(pid(), integer(), :twitter | :reddit) :: boolean()
  def can_see_platform?(pid, agent_id, platform) do
    GenServer.call(pid, {:can_see_platform, agent_id, platform})
  end

  @doc """
  Gets recent cross-platform mentions for an agent.
  """
  @spec get_cross_platform_context(pid(), integer(), :twitter | :reddit) :: [map()]
  def get_cross_platform_context(pid, agent_id, platform) do
    GenServer.call(pid, {:get_context, agent_id, platform})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      simulation_id: Keyword.fetch!(opts, :simulation_id),
      agents: %{},
      # agent_id => %{name, platforms: []}
      interactions: [],
      # List of cross_platform_event
      stats: %{
        twitter_to_reddit: 0,
        reddit_to_twitter: 0,
        total_interactions: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:register_agent, agent_id, name, platform}, state) do
    agent = Map.get(state.agents, agent_id, %{name: name, platforms: []})

    updated_agent =
      if platform not in agent.platforms do
        %{agent | platforms: [platform | agent.platforms]}
      else
        agent
      end

    new_agents = Map.put(state.agents, agent_id, updated_agent)

    {:noreply, %{state | agents: new_agents}}
  end

  def handle_cast({:record_interaction, interaction}, state) do
    # Normalize and validate the interaction
    normalized = normalize_interaction(interaction)

    # Update stats
    new_stats = update_stats(state.stats, normalized)

    # Store interaction (keep last 1000)
    new_interactions = [normalized | state.interactions] |> Enum.take(1000)

    {:noreply, %{state | interactions: new_interactions, stats: new_stats}}
  end

  @impl true
  def handle_call(:get_agent_platforms, _from, state) do
    platforms =
      Enum.map(state.agents, fn {agent_id, data} ->
        %{
          agent_id: agent_id,
          name: data.name,
          platforms: data.platforms
        }
      end)

    {:reply, platforms, state}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  def handle_call({:can_see_platform, agent_id, platform}, _from, state) do
    agent = Map.get(state.agents, agent_id)

    can_see =
      if agent do
        # Agent can see platform if:
        # 1. They're on that platform, OR
        # 2. They've been mentioned by someone on that platform recently
        platform in agent.platforms or has_recent_mention(state.interactions, agent_id, platform)
      else
        false
      end

    {:reply, can_see, state}
  end

  def handle_call({:get_context, agent_id, platform}, _from, state) do
    # Get recent interactions from the other platform that mention this agent
    other_platform = if platform == :twitter, do: :reddit, else: :twitter

    context =
      state.interactions
      |> Enum.filter(fn interaction ->
        interaction.from_platform == other_platform and
          (interaction.target_agent == agent_id or
             mentions_agent?(interaction, agent_id, state.agents))
      end)
      |> Enum.take(10)

    {:reply, context, state}
  end

  # Private functions

  defp via_tuple(simulation_id) do
    {:via, Registry, {Miroex.Simulation.AgentRegistry, {:coordinator, simulation_id}}}
  end

  defp normalize_interaction(interaction) do
    %{
      type: Map.get(interaction, :type, :mention),
      from_platform: Map.fetch!(interaction, :from_platform),
      to_platform: Map.fetch!(interaction, :to_platform),
      source_agent: Map.fetch!(interaction, :source_agent),
      target_agent: Map.get(interaction, :target_agent),
      content: Map.get(interaction, :content, ""),
      timestamp: Map.get(interaction, :timestamp, DateTime.utc_now())
    }
  end

  defp update_stats(stats, interaction) do
    base = %{stats | total_interactions: stats.total_interactions + 1}

    case {interaction.from_platform, interaction.to_platform} do
      {:twitter, :reddit} ->
        %{base | twitter_to_reddit: stats.twitter_to_reddit + 1}

      {:reddit, :twitter} ->
        %{base | reddit_to_twitter: stats.reddit_to_twitter + 1}

      _ ->
        base
    end
  end

  defp has_recent_mention(interactions, agent_id, platform, within_seconds \\ 3600) do
    cutoff = DateTime.add(DateTime.utc_now(), -within_seconds, :second)

    Enum.any?(interactions, fn interaction ->
      interaction.from_platform == platform and
        interaction.target_agent == agent_id and
        DateTime.compare(interaction.timestamp, cutoff) == :gt
    end)
  end

  defp mentions_agent?(interaction, agent_id, agents) do
    agent = Map.get(agents, agent_id)

    if agent do
      String.contains?(interaction.content, agent.name)
    else
      false
    end
  end
end
