defmodule Miroex.Graph.FactCreator do
  @moduledoc """
  Creates graph facts (edges) from agent actions.

  When agents perform actions in the simulation, this module
  creates corresponding graph edges to track relationships
  and interactions with temporal validity.
  """

  alias Miroex.Graph.Temporal
  alias Miroex.Graph.Memgraph

  @type action :: %{
          action_type: atom(),
          agent_id: integer(),
          agent_name: String.t(),
          target_id: integer() | nil,
          target_name: String.t() | nil,
          content: String.t(),
          round: integer(),
          timestamp: DateTime.t()
        }

  @type graph_fact :: %{
          from: String.t(),
          to: String.t(),
          type: String.t(),
          fact: String.t(),
          action_type: atom(),
          round: integer(),
          timestamp: DateTime.t()
        }

  # Action type to edge type mapping
  @action_to_edge_type %{
    :create_post => "POSTED",
    :like_post => "LIKED",
    :comment_post => "COMMENTED_ON",
    :follow_user => "FOLLOWS",
    :retweet_post => "RETWEETED",
    :reply_post => "REPLIED_TO",
    :mention => "MENTIONED"
  }

  @doc """
  Creates graph facts from a simulation action.

  ## Parameters
    - graph_id: The graph ID
    - action: The simulation action map
    - agent_info: Map with agent name and other details

  ## Returns
    {:ok, list_of_facts} | {:error, reason}
  """
  @spec create_facts_from_action(String.t(), map(), map()) ::
          {:ok, [graph_fact()]} | {:error, term()}
  def create_facts_from_action(graph_id, action, agent_info) do
    agent_name = agent_info[:name] || "Agent #{action.agent_id}"
    action_type = action.action_type

    # Get edge type based on action
    edge_type = Map.get(@action_to_edge_type, action_type, "INTERACTED_WITH")

    # Determine target
    target_name = determine_target(action, agent_name)

    # Create the fact
    fact_text = build_fact_text(action_type, agent_name, target_name, action)

    fact = %{
      from: agent_name,
      to: target_name,
      type: edge_type,
      fact: fact_text,
      action_type: action_type,
      round: action.round,
      timestamp: action.timestamp
    }

    # Store in Memgraph
    case store_fact(graph_id, fact) do
      :ok -> {:ok, [fact]}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates facts from a batch of actions.

  ## Parameters
    - graph_id: The graph ID
    - actions: List of action maps
    - agent_info_map: Map of agent_id => agent details

  ## Returns
    {:ok, list_of_facts} | {:error, reason}
  """
  @spec create_facts_from_actions(String.t(), [map()], map()) ::
          {:ok, [graph_fact()]} | {:error, term()}
  def create_facts_from_actions(graph_id, actions, agent_info_map) do
    results =
      Enum.reduce(actions, {:ok, []}, fn action, {:ok, acc_facts} ->
        agent_info = Map.get(agent_info_map, action.agent_id, %{name: "Agent #{action.agent_id}"})

        case create_facts_from_action(graph_id, action, agent_info) do
          {:ok, facts} -> {:ok, acc_facts ++ facts}
          {:error, reason} -> {:error, reason}
        end
      end)

    results
  end

  @doc """
  Creates an "influenced by" relationship between agents.

  ## Parameters
    - graph_id: The graph ID
    - influencer_id: The agent who influenced
    - influenced_id: The agent who was influenced
    - influence_type: Type of influence (e.g., :retweet, :reply, :mention)
    - metadata: Additional context

  ## Returns
    :ok | {:error, reason}
  """
  @spec create_influence_relationship(String.t(), String.t(), String.t(), atom(), map()) ::
          :ok | {:error, term()}
  def create_influence_relationship(
        graph_id,
        influencer_name,
        influenced_name,
        influence_type,
        metadata \\ %{}
      ) do
    fact_text = "#{influenced_name} was influenced by #{influencer_name} (#{influence_type})"

    temporal_edge =
      Temporal.create_edge(
        influenced_name,
        influencer_name,
        "INFLUENCED_BY",
        fact_text,
        Map.get(metadata, :timestamp)
      )

    store_temporal_edge(graph_id, temporal_edge)
  end

  @doc """
  Creates a temporal fact edge.

  ## Parameters
    - graph_id: The graph ID
    - source_name: Source entity name
    - target_name: Target entity name
    - relationship_type: Type of relationship
    - fact: Description of the fact
    - valid_from: When the fact becomes valid
    - valid_until: When the fact becomes invalid (nil = permanent)

  ## Returns
    :ok | {:error, reason}
  """
  @spec create_temporal_fact(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          DateTime.t(),
          DateTime.t() | nil
        ) :: :ok | {:error, term()}
  def create_temporal_fact(
        graph_id,
        source_name,
        target_name,
        relationship_type,
        fact,
        valid_from,
        valid_until \\ nil
      ) do
    temporal_edge =
      Temporal.create_edge(source_name, target_name, relationship_type, fact, valid_from)

    edge =
      if valid_until do
        Temporal.set_validity(temporal_edge, valid_from, valid_until)
      else
        temporal_edge
      end

    store_temporal_edge(graph_id, edge)
  end

  @doc """
  Invalidates a fact in the graph.

  ## Parameters
    - graph_id: The graph ID
    - from: Source entity name
    - to: Target entity name
    - type: Relationship type
    - invalid_at: When the fact becomes invalid

  ## Returns
    :ok | {:error, reason}
  """
  @spec invalidate_fact(String.t(), String.t(), String.t(), String.t(), DateTime.t()) ::
          :ok | {:error, term()}
  def invalidate_fact(graph_id, from, to, type, invalid_at) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e1:Entity {name: $from})
    MATCH (e1)-[r:RELATES {type: $type}]->(e2:Entity {name: $to})
    SET r.invalid_at = datetime($invalid_at)
    RETURN r
    """

    case Memgraph.query(cypher, %{
           graph_id: graph_id,
           from: from,
           to: to,
           type: type,
           invalid_at: DateTime.to_iso8601(invalid_at)
         }) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets all facts created from simulation actions for a graph.

  ## Parameters
    - graph_id: The graph ID
    - opts: Options including :since_round and :limit

  ## Returns
    {:ok, [graph_fact]} | {:error, reason}
  """
  @spec get_simulation_facts(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def get_simulation_facts(graph_id, opts \\ []) do
    since_round = Keyword.get(opts, :since_round, 0)
    limit = Keyword.get(opts, :limit, 1000)

    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e1:Entity)-[r:RELATES]->(e2:Entity)
    WHERE r.round >= $since_round
    RETURN e1.name as from,
           e2.name as to,
           r.type as type,
           r.fact as fact,
           r.round as round,
           r.timestamp as timestamp,
           r.valid_at as valid_at,
           r.invalid_at as invalid_at
    ORDER BY r.round DESC, r.timestamp DESC
    LIMIT #{limit}
    """

    case Memgraph.query(cypher, %{graph_id: graph_id, since_round: since_round}) do
      {:ok, facts} -> {:ok, facts}
      error -> error
    end
  end

  @doc """
  Gets facts by action type.

  ## Parameters
    - graph_id: The graph ID
    - action_type: The action type to filter by
    - opts: Additional options

  ## Returns
    {:ok, [graph_fact]} | {:error, reason}
  """
  @spec get_facts_by_action_type(String.t(), atom(), keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def get_facts_by_action_type(graph_id, action_type, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    edge_type = Map.get(@action_to_edge_type, action_type, "INTERACTED_WITH")

    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e1:Entity)-[r:RELATES {type: $type}]->(e2:Entity)
    RETURN e1.name as from,
           e2.name as to,
           r.type as type,
           r.fact as fact,
           r.round as round,
           r.timestamp as timestamp
    ORDER BY r.timestamp DESC
    LIMIT #{limit}
    """

    case Memgraph.query(cypher, %{graph_id: graph_id, type: edge_type}) do
      {:ok, facts} -> {:ok, facts}
      error -> error
    end
  end

  # Private functions

  defp determine_target(action, agent_name) do
    case action do
      %{target_name: target_name} when not is_nil(target_name) and target_name != "" ->
        target_name

      %{target_id: target_id} when not is_nil(target_id) ->
        "Agent #{target_id}"

      _ ->
        # Self-action or no target
        agent_name
    end
  end

  defp build_fact_text(:create_post, agent_name, _target, action) do
    content_preview = String.slice(action.content || "", 0, 50)
    "#{agent_name} created a post: #{content_preview}..."
  end

  defp build_fact_text(:like_post, agent_name, target_name, _action) do
    "#{agent_name} liked a post by #{target_name}"
  end

  defp build_fact_text(:comment_post, agent_name, target_name, action) do
    content_preview = String.slice(action.content || "", 0, 50)
    "#{agent_name} commented on #{target_name}'s post: #{content_preview}..."
  end

  defp build_fact_text(:follow_user, agent_name, target_name, _action) do
    "#{agent_name} followed #{target_name}"
  end

  defp build_fact_text(:retweet_post, agent_name, target_name, action) do
    content_preview = String.slice(action.content || "", 0, 50)
    "#{agent_name} retweeted #{target_name}'s post: #{content_preview}..."
  end

  defp build_fact_text(:reply_post, agent_name, target_name, action) do
    content_preview = String.slice(action.content || "", 0, 50)
    "#{agent_name} replied to #{target_name}'s post: #{content_preview}..."
  end

  defp build_fact_text(:mention, agent_name, target_name, _action) do
    "#{agent_name} mentioned #{target_name}"
  end

  defp build_fact_text(_action_type, agent_name, target_name, _action) do
    "#{agent_name} interacted with #{target_name}"
  end

  defp store_fact(graph_id, fact) do
    temporal_edge =
      Temporal.create_edge(
        fact.from,
        fact.to,
        fact.type,
        fact.fact,
        fact.timestamp
      )

    store_temporal_edge(graph_id, temporal_edge)
  end

  defp store_temporal_edge(graph_id, edge) do
    props = Temporal.to_memgraph_props(edge)

    cypher = """
    MATCH (g:Graph {id: $graph_id})
    MATCH (e1:Entity {name: $from})
    MATCH (e2:Entity {name: $to})
    MERGE (e1)-[r:RELATES {
      type: $type,
      fact: $fact,
      created_at: datetime($created_at),
      valid_at: datetime($valid_at),
      invalid_at: $invalid_at,
      expired_at: $expired_at
    }]->(e2)
    RETURN r
    """

    params =
      Map.merge(props, %{
        "graph_id" => graph_id,
        "from" => edge.from,
        "to" => edge.to
      })

    case Memgraph.query(cypher, params) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
