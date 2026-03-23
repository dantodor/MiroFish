defmodule Miroex.AI.Tools.GraphSearch do
  @moduledoc """
  Graph search tool for report agent.
  """
  alias Miroex.Graph.EntityReader

  def execute(graph_id, query) do
    case EntityReader.get_entities(graph_id) do
      {:ok, entities} ->
        filtered =
          Enum.filter(entities, fn entity ->
            name = entity["name"] || ""
            type = entity["type"] || ""

            String.contains?(String.downcase(name), String.downcase(query)) ||
              String.contains?(String.downcase(type), String.downcase(query))
          end)

        {:ok, filtered}

      error ->
        error
    end
  end

  def execute_by_type(graph_id, entity_type) do
    EntityReader.get_entities_by_type(graph_id, entity_type)
  end

  def get_types(graph_id) do
    EntityReader.get_entity_types(graph_id)
  end

  def get_graph_data(graph_id) do
    EntityReader.get_graph_data(graph_id)
  end

  @doc """
  Deep hybrid search combining entity search with relationship context.
  This searches for entities and returns them with their related entities/edges
  to provide richer context for the report agent.
  """
  @spec insight_forge(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def insight_forge(graph_id, query, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 10)

    with {:ok, entities} <- execute(graph_id, query),
         {:ok, relations} <- EntityReader.get_relations(graph_id) do
      scored_entities = score_entities(entities, query)

      enriched =
        Enum.take(scored_entities, top_k)
        |> Enum.map(&enrich_with_relations(&1, relations))

      {:ok,
       %{
         query: query,
         results: enriched,
         total_found: length(entities),
         returned: length(enriched)
       }}
    end
  end

  defp score_entities(entities, query) do
    query_lower = String.downcase(query)

    Enum.map(entities, fn entity ->
      name = String.downcase(entity["name"] || "")
      type = String.downcase(entity["type"] || "")

      score =
        cond do
          name == query_lower -> 100
          String.starts_with?(name, query_lower) -> 80
          String.contains?(name, query_lower) -> 60
          String.contains?(type, query_lower) -> 40
          true -> 10
        end

      Map.put(entity, :relevance_score, score)
    end)
    |> Enum.sort_by(& &1.relevance_score, {:desc, 0})
  end

  defp enrich_with_relations(entity, all_relations) do
    entity_name = entity["name"]

    related =
      Enum.filter(all_relations, fn rel ->
        rel["from"] == entity_name || rel["to"] == entity_name
      end)
      |> Enum.map(fn rel ->
        if rel["from"] == entity_name do
          %{direction: :outgoing, to: rel["to"], type: rel["type"]}
        else
          %{direction: :incoming, from: rel["from"], type: rel["type"]}
        end
      end)

    Map.put(entity, :related_relations, related)
  end

  @doc """
  Broad search including all entity types and relations.
  Unlike insight_forge which is focused, panorama returns a complete
  overview of the graph data structure.
  """
  @spec panorama_search(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def panorama_search(graph_id, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 20)

    with {:ok, entities} <- EntityReader.get_entities(graph_id),
         {:ok, relations} <- EntityReader.get_relations(graph_id),
         {:ok, types} <- EntityReader.get_entity_types(graph_id) do
      by_type = Enum.group_by(entities, & &1["type"])

      top_per_type =
        by_type
        |> Enum.map(fn {type, ents} ->
          {type, Enum.take(ents, div(top_k, max(1, length(types))))}
        end)
        |> Enum.into(%{})

      {:ok,
       %{
         overview: %{
           total_entities: length(entities),
           total_relations: length(relations),
           entity_types: types,
           types_count: length(types)
         },
         entities: %{
           all: Enum.take(entities, top_k),
           by_type: top_per_type
         },
         relations: %{
           all: Enum.take(relations, top_k * 2),
           sample: Enum.take(relations, 5)
         }
       }}
    end
  end

  @doc """
  Get recursive relationship chains starting from an entity.
  Returns all paths up to specified depth.
  """
  @spec get_relation_chains(String.t(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def get_relation_chains(graph_id, entity_name, opts \\ []) do
    depth = Keyword.get(opts, :depth, 3)
    max_paths = Keyword.get(opts, :max_paths, 20)

    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(start:Entity {name: $name})
    MATCH path = (start)-[:RELATES*1..#{depth}]->(end:Entity)
    WHERE start:Entity AND end:Entity
    RETURN path,
           nodes(path) as chain_nodes,
           relationships(path) as chain_relations
    LIMIT #{max_paths}
    """

    case Miroex.Memgraph.query(cypher, %{graph_id: graph_id, name: entity_name}) do
      {:ok, paths} when is_list(paths) ->
        formatted = Enum.map(paths, &format_path/1)
        {:ok, formatted}

      {:ok, []} ->
        {:ok, []}

      error ->
        error
    end
  end

  defp format_path(%{"chain_nodes" => nodes, "chain_relations" => rels}) do
    node_names =
      Enum.map(nodes, fn n ->
        case n do
          %{"name" => name} -> name
          n when is_map(n) -> Map.get(n, "name", "unknown")
          _ -> "unknown"
        end
      end)

    rel_types =
      Enum.map(rels, fn r ->
        case r do
          %{"type" => type} -> type
          r when is_map(r) -> Map.get(r, "type", "RELATED")
          _ -> "RELATED"
        end
      end)

    %{
      chain: Enum.join(node_names, " → "),
      length: length(node_names),
      types: rel_types
    }
  end

  @doc """
  Interview agents about a specific topic.

  This function interviews simulation agents to gather their perspectives on a topic.
  It uses the existing Agent.interview/2 function via the Orchestrator.

  ## Parameters
    - simulation_id: The simulation ID to find agents
    - interview_topic: The topic to ask agents about
    - opts: Optional parameters including :max_agents

  ## Returns
    {:ok, [%{agent_name, agent_id, platform, response}]} or {:error, reason}
  """
  @spec interview_agents(String.t(), String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def interview_agents(simulation_id, interview_topic, opts \\ [])
      when is_binary(simulation_id) and is_binary(interview_topic) do
    max_agents = Keyword.get(opts, :max_agents, 5)

    with {:ok, entities} <- EntityReader.get_entities(simulation_id),
         ranked_agents = score_and_rank_agents(entities, interview_topic),
         top_agents <- Enum.take(ranked_agents, max_agents),
         results <- interview_top_agents(top_agents, simulation_id, interview_topic) do
      {:ok, results}
    else
      {:error, reason} ->
        {:error, reason}

      reason when is_atom(reason) ->
        {:error, reason}
    end
  rescue
    e ->
      {:error, "interview_agents failed: #{inspect(e)}"}
  end

  defp score_and_rank_agents(entities, topic) do
    topic_lower = String.downcase(topic)

    entities
    |> Enum.map(fn entity ->
      name = entity["name"] || ""
      type = entity["type"] || ""

      name_score = calculate_name_score(name, topic_lower)
      type_score = calculate_type_score(type, topic_lower)

      %{
        name: name,
        type: type,
        agent_id: abs(String.length(name)),
        score: name_score + type_score
      }
    end)
    |> Enum.sort_by(& &1.score, {:desc, 0})
  end

  defp calculate_name_score(name, topic_lower) do
    name_lower = String.downcase(name)

    cond do
      name_lower == topic_lower -> 100
      String.starts_with?(name_lower, topic_lower) -> 80
      String.contains?(name_lower, topic_lower) -> 60
      true -> 0
    end
  end

  defp calculate_type_score(type, topic_lower) do
    type_lower = String.downcase(type)

    if String.contains?(type_lower, topic_lower) or String.contains?(topic_lower, type_lower) do
      30
    else
      0
    end
  end

  defp interview_top_agents(agents, simulation_id, topic) do
    agents
    |> Enum.map(fn agent ->
      agent_name = agent.name
      agent_id = agent.agent_id

      response =
        case Miroex.Simulation.AgentRegistry.lookup(simulation_id, agent_id) do
          {:ok, agent_pid} ->
            case Miroex.Simulation.Agent.interview(agent_pid, topic) do
              {:ok, response} -> response
              {:error, reason} -> "Unable to interview: #{inspect(reason)}"
            end

          :error ->
            "Agent not currently active in simulation"
        end

      %{
        agent_name: agent_name,
        agent_id: agent_id,
        type: agent.type,
        topic: topic,
        response: response
      }
    end)
  end
end
