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

  alias Miroex.AI.Openrouter

  @doc """
  Deep hybrid search combining entity search with relationship context.
  This searches for entities and returns them with their related entities/edges
  to provide richer context for the report agent.

  Enhanced with sub-query generation for more comprehensive results.
  """
  @spec insight_forge(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def insight_forge(graph_id, query, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 10)
    simulation_requirement = Keyword.get(opts, :simulation_requirement, "")

    # Generate sub-queries to search more comprehensively
    sub_queries = generate_sub_queries(query, simulation_requirement)

    # Search for each sub-query and combine results
    all_results =
      sub_queries
      |> Enum.flat_map(fn sub_query ->
        case execute(graph_id, sub_query) do
          {:ok, entities} -> entities
          _ -> []
        end
      end)
      |> Enum.uniq_by(& &1["name"])

    with {:ok, relations} <- EntityReader.get_relations(graph_id) do
      # Score and rank all found entities
      scored_entities = score_entities_enhanced(all_results, query, sub_queries)

      # Take top k and enrich with relations
      enriched =
        scored_entities
        |> Enum.take(top_k)
        |> Enum.map(&enrich_with_relations(&1, relations))

      {:ok,
       %{
         query: query,
         sub_queries: sub_queries,
         results: enriched,
         total_found: length(all_results),
         returned: length(enriched)
       }}
    end
  end

  @doc """
  Generates sub-queries from the original query to search more comprehensively.

  Uses LLM to decompose the query into related search terms.
  """
  @spec generate_sub_queries(String.t(), String.t()) :: [String.t()]
  def generate_sub_queries(query, simulation_requirement \\ "") do
    system_prompt = """
    You are a search query optimizer. Your task is to break down a complex query
    into 3-5 related sub-queries that will help find all relevant information.

    Guidelines:
    - Each sub-query should be a short phrase (1-4 words)
    - Sub-queries should cover different aspects of the topic
    - Include variations, synonyms, and related concepts
    - Focus on entities and relationships

    Return ONLY a JSON array of strings.
    """

    user_prompt =
      if simulation_requirement != "" do
        """
        Simulation Context: #{simulation_requirement}

        Main Query: #{query}

        Generate 3-5 sub-queries to search for related information.
        """
      else
        """
        Main Query: #{query}

        Generate 3-5 sub-queries to search for related information.
        """
      end

    case Openrouter.chat([
           %{role: "system", content: system_prompt},
           %{role: "user", content: user_prompt}
         ]) do
      {:ok, %{"content" => content}} ->
        case Jason.decode(content) do
          {:ok, sub_queries} when is_list(sub_queries) ->
            # Include original query in sub-queries
            [query | sub_queries]

          _ ->
            # Fallback: generate simple sub-queries
            generate_fallback_sub_queries(query)
        end

      _error ->
        generate_fallback_sub_queries(query)
    end
  end

  defp generate_fallback_sub_queries(query) do
    query_words = String.split(query, ~r/\s+/, trim: true)

    sub_queries =
      if length(query_words) > 1 do
        # Generate combinations
        [
          query,
          List.first(query_words),
          List.last(query_words),
          Enum.join(Enum.take(query_words, 2), " ")
        ]
      else
        [query]
      end

    Enum.uniq(sub_queries)
  end

  defp score_entities_enhanced(entities, main_query, sub_queries) do
    main_query_lower = String.downcase(main_query)
    sub_queries_lower = Enum.map(sub_queries, &String.downcase/1)

    entities
    |> Enum.map(fn entity ->
      name = String.downcase(entity["name"] || "")
      type = String.downcase(entity["type"] || "")

      # Score based on main query
      main_score = calculate_relevance_score(name, type, main_query_lower)

      # Bonus for matching sub-queries
      sub_query_bonus =
        sub_queries_lower
        |> Enum.count(fn sq ->
          String.contains?(name, sq) or String.contains?(type, sq)
        end)
        |> Kernel.*(10)

      total_score = main_score + sub_query_bonus

      Map.put(entity, :relevance_score, total_score)
    end)
    |> Enum.sort_by(& &1.relevance_score, {:desc, 0})
  end

  defp calculate_relevance_score(name, type, query) do
    cond do
      name == query -> 100
      String.starts_with?(name, query) -> 80
      String.contains?(name, query) -> 60
      String.contains?(type, query) -> 40
      true -> 10
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

  alias Miroex.Simulation.{AgentSelector, BatchInterview}

  @doc """
  Interview agents about a specific topic.

  This function interviews simulation agents to gather their perspectives on a topic.
  Uses LLM-based agent selection and supports dual-platform interviews.

  ## Parameters
    - simulation_id: The simulation ID to find agents
    - interview_topic: The topic to ask agents about
    - opts: Optional parameters including:
      - :max_agents - Maximum agents to interview (default: 5)
      - :platform - :twitter | :reddit | :both (default: :both)
      - :simulation_requirement - Context for agent selection

  ## Returns
    {:ok, %{
      interviews: [%{agent_name, agent_id, platform, response}],
      selection_reasoning: "...",
      questions: ["..."]
    }} or {:error, reason}
  """
  @spec interview_agents(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def interview_agents(simulation_id, interview_topic, opts \\ [])
      when is_binary(simulation_id) and is_binary(interview_topic) do
    max_agents = Keyword.get(opts, :max_agents, 5)
    platform = Keyword.get(opts, :platform, :both)
    simulation_requirement = Keyword.get(opts, :simulation_requirement, nil)

    with %{selected_agents: selected, reasoning: reasoning} <-
           AgentSelector.select_agents(
             simulation_id,
             interview_topic,
             max_agents,
             simulation_requirement
           ),
         questions =
           BatchInterview.generate_interview_questions(interview_topic, simulation_requirement, 3),
         combined_prompt = BatchInterview.format_interview_prompt(questions),
         interview_requests = build_interview_requests(selected, combined_prompt),
         {:ok, %{results: results}} <-
           BatchInterview.batch_interview(simulation_id, interview_requests, platform) do
      # Group results by agent
      grouped =
        results
        |> Enum.group_by(& &1.agent_id)
        |> Enum.map(fn {_agent_id, agent_results} ->
          # Combine platform results for the same agent
          primary_result = List.first(agent_results)

          responses =
            Enum.map(agent_results, fn r ->
              %{
                platform: r.platform,
                response: r.response
              }
            end)

          %{
            agent_id: primary_result.agent_id,
            agent_name: primary_result.agent_name,
            responses: responses
          }
        end)

      {:ok,
       %{
         interviews: grouped,
         selection_reasoning: reasoning,
         questions: questions,
         total_interviewed: length(selected)
       }}
    else
      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Interview failed"}
    end
  rescue
    e ->
      {:error, "interview_agents failed: #{inspect(e)}"}
  end

  # These functions are kept for potential future use but currently unused
  # defp calculate_name_score(name, topic_lower) do
  #   name_lower = String.downcase(name)
  #
  #   cond do
  #     name_lower == topic_lower -> 100
  #     String.starts_with?(name_lower, topic_lower) -> 80
  #     String.contains?(name_lower, topic_lower) -> 60
  #     true -> 0
  #   end
  # end
  #
  # defp calculate_type_score(type, topic_lower) do
  #   type_lower = String.downcase(type)
  #
  #   if String.contains?(type_lower, topic_lower) or String.contains?(topic_lower, type_lower) do
  #     30
  #   else
  #     0
  #   end
  # end

  # This function is kept for potential future use but currently unused
  # defp interview_top_agents(agents, simulation_id, topic) do
  #   agents
  #   |> Enum.map(fn agent ->
  #     agent_name = agent.name
  #     agent_id = agent.agent_id
  #
  #     response =
  #       case Miroex.Simulation.AgentRegistry.lookup(simulation_id, agent_id) do
  #         {:ok, agent_pid} ->
  #           case Miroex.Simulation.Agent.interview(agent_pid, topic) do
  #             {:ok, response} -> response
  #             {:error, reason} -> "Unable to interview: #{inspect(reason)}"
  #           end
  #
  #         :error ->
  #           "Agent not currently active in simulation"
  #       end
  #
  #     %{
  #       agent_name: agent_name,
  #       agent_id: agent_id,
  #       type: agent.type,
  #       topic: topic,
  #       response: response
  #     }
  #   end)
  # end
  #
  # defp score_and_rank_agents(entities, topic) do
  #   topic_lower = String.downcase(topic)
  #
  #   entities
  #   |> Enum.map(fn entity ->
  #     name = entity["name"] || ""
  #     type = entity["type"] || ""
  #
  #     name_score = calculate_name_score(name, topic_lower)
  #     type_score = calculate_type_score(type, topic_lower)
  #
  #     %{
  #       name: name,
  #       type: type,
  #       agent_id: abs(String.length(name)),
  #       score: name_score + type_score
  #     }
  #   end)
  #   |> Enum.sort_by(& &1.score, {:desc, 0})
  # end

  defp build_interview_requests(selected_agents, prompt) do
    Enum.map(selected_agents, fn agent ->
      %{
        agent_id: agent.agent_id,
        prompt: prompt
      }
    end)
  end
end
