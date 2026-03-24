defmodule Miroex.Graph.EntityReader do
  @moduledoc """
  Read and filter entities from Memgraph knowledge graph.
  """
  alias Miroex.Memgraph

  @spec get_entities(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_entities(graph_id) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e:Entity)
    RETURN e.name as name, e.type as type, e.properties as properties
    ORDER BY e.type, e.name
    """

    case Memgraph.query(cypher, %{graph_id: graph_id}) do
      {:ok, entities} -> {:ok, Enum.uniq_by(entities, & &1["name"])}
      error -> error
    end
  end

  @doc """
  Get entities with pagination.
  Returns limited results to avoid memory issues with large graphs.
  """
  @spec get_entities_paginated(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_entities_paginated(graph_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 100)

    offset = (page - 1) * page_size

    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e:Entity)
    RETURN e.name as name, e.type as type, e.properties as properties
    ORDER BY e.type, e.name
    SKIP $offset
    LIMIT $limit
    """

    count_cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e:Entity)
    RETURN count(e) as total
    """

    with {:ok, rows} <-
           Memgraph.query(cypher, %{graph_id: graph_id, offset: offset, limit: page_size}),
         {:ok, [%{"total" => total}]} <- Memgraph.query(count_cypher, %{graph_id: graph_id}) do
      {:ok,
       %{
         entities: Enum.uniq_by(rows, & &1["name"]),
         pagination: %{
           page: page,
           page_size: page_size,
           total: total,
           total_pages: ceil(total / page_size),
           has_next: offset + page_size < total,
           has_prev: page > 1
         }
       }}
    end
  end

  @spec get_entities_by_type(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_entities_by_type(graph_id, entity_type) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e:Entity {type: $type})
    RETURN e.name as name, e.type as type, e.properties as properties
    ORDER BY e.name
    """

    case Memgraph.query(cypher, %{graph_id: graph_id, type: entity_type}) do
      {:ok, entities} -> {:ok, entities}
      error -> error
    end
  end

  @spec get_entity_types(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def get_entity_types(graph_id) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e:Entity)
    RETURN DISTINCT e.type as type
    ORDER BY type
    """

    case Memgraph.query(cypher, %{graph_id: graph_id}) do
      {:ok, types} -> {:ok, Enum.map(types, & &1["type"])}
      error -> error
    end
  end

  @spec get_entity(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_entity(graph_id, entity_name) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e:Entity {name: $name})
    RETURN e.name as name, e.type as type, e.properties as properties
    LIMIT 1
    """

    case Memgraph.query(cypher, %{graph_id: graph_id, name: entity_name}) do
      {:ok, [entity | _]} -> {:ok, entity}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @spec get_graph_data(String.t()) :: {:ok, map()} | {:error, term()}
  def get_graph_data(graph_id) do
    with {:ok, nodes} <- get_entities(graph_id),
         {:ok, edges} <- get_relations(graph_id) do
      {:ok, %{nodes: nodes, edges: edges}}
    end
  end

  @spec get_relations(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_relations(graph_id) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e1:Entity)-[r:RELATES]->(e2:Entity)
    RETURN e1.name as from,
           e2.name as to,
           r.type as type,
           r.fact as fact,
           r.created_at as created_at,
           r.valid_at as valid_at,
           r.invalid_at as invalid_at,
           r.expired_at as expired_at
    """

    case Memgraph.query(cypher, %{graph_id: graph_id}) do
      {:ok, relations} -> {:ok, relations}
      error -> error
    end
  end

  @spec get_active_relations(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_active_relations(graph_id) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e1:Entity)-[r:RELATES]->(e2:Entity)
    WHERE r.invalid_at IS NULL
       OR r.invalid_at > datetime()
    RETURN e1.name as from,
           e2.name as to,
           r.type as type,
           r.fact as fact,
           r.created_at as created_at,
           r.valid_at as valid_at
    """

    case Memgraph.query(cypher, %{graph_id: graph_id}) do
      {:ok, relations} -> {:ok, relations}
      error -> error
    end
  end

  @spec get_historical_relations(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_historical_relations(graph_id) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e1:Entity)-[r:RELATES]->(e2:Entity)
    WHERE r.invalid_at IS NOT NULL
       OR r.expired_at IS NOT NULL
    RETURN e1.name as from,
           e2.name as to,
           r.type as type,
           r.fact as fact,
           r.created_at as created_at,
           r.valid_at as valid_at,
           r.invalid_at as invalid_at,
           r.expired_at as expired_at
    ORDER BY r.created_at DESC
    """

    case Memgraph.query(cypher, %{graph_id: graph_id}) do
      {:ok, relations} -> {:ok, relations}
      error -> error
    end
  end

  @spec get_relations_as_of(String.t(), DateTime.t()) :: {:ok, [map()]} | {:error, term()}
  def get_relations_as_of(graph_id, datetime) do
    datetime_str = DateTime.to_iso8601(datetime)

    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e1:Entity)-[r:RELATES]->(e2:Entity)
    WHERE r.valid_at <= datetime($as_of)
      AND (r.invalid_at IS NULL OR r.invalid_at > datetime($as_of))
    RETURN e1.name as from,
           e2.name as to,
           r.type as type,
           r.fact as fact,
           r.valid_at as valid_at
    """

    case Memgraph.query(cypher, %{graph_id: graph_id, as_of: datetime_str}) do
      {:ok, relations} -> {:ok, relations}
      error -> error
    end
  end

  @spec delete_graph(String.t()) :: :ok | {:error, term()}
  def delete_graph(graph_id) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})
    DETACH DELETE g
    """

    case Memgraph.query(cypher, %{graph_id: graph_id}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Get entity with full context: attributes, relations, related entities.
  This provides the rich context needed for detailed persona generation.
  """
  @spec get_entity_with_context(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_entity_with_context(graph_id, entity_name) do
    with {:ok, entity} <- get_entity(graph_id, entity_name),
         {:ok, relations} <- get_relations_for_entity(graph_id, entity_name),
         {:ok, related_entities} <- get_related_entity_details(graph_id, relations) do
      context = build_entity_context(entity, relations, related_entities)

      {:ok,
       Map.merge(entity, %{
         relations: relations,
         related_entities: related_entities,
         context: context
       })}
    end
  end

  @doc """
  Get all relations (both incoming and outgoing) for a specific entity.
  """
  @spec get_relations_for_entity(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_relations_for_entity(graph_id, entity_name) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e1:Entity {name: $name})
    OPTIONAL MATCH (e1)-[r:RELATES]->(e2:Entity)
    OPTIONAL MATCH (e3:Entity)-[r2:RELATES]->(e1)
    RETURN 
      coalesce(e1.name, e2.name, e3.name) as entity,
      CASE 
        WHEN e1.name = $name THEN 'outgoing'
        ELSE 'incoming'
      END as direction,
      CASE 
        WHEN e1.name = $name THEN coalesce(e2.name, '')
        ELSE coalesce(e3.name, '')
      END as related_to,
      CASE 
        WHEN e1.name = $name THEN type(r)
        ELSE type(r2)
      END as relation_type,
      CASE 
        WHEN e1.name = $name THEN r.fact
        ELSE r2.fact
      END as fact
    """

    case Memgraph.query(cypher, %{graph_id: graph_id, name: entity_name}) do
      {:ok, relations} when is_list(relations) ->
        formatted =
          relations
          |> Enum.filter(fn r -> r["related_to"] != "" and r["related_to"] != nil end)
          |> Enum.map(fn r ->
            %{
              direction: String.to_existing_atom(r["direction"]),
              related_to: r["related_to"],
              type: r["relation_type"] || "RELATES",
              fact: r["fact"] || ""
            }
          end)

        {:ok, formatted}

      error ->
        error
    end
  end

  @doc """
  Get details for entities related to the given entity.
  """
  @spec get_related_entity_details(String.t(), [map()]) :: {:ok, [map()]} | {:error, term()}
  def get_related_entity_details(_graph_id, relations) when relations == [] or relations == nil do
    {:ok, []}
  end

  def get_related_entity_details(graph_id, relations) do
    related_names =
      relations
      |> Enum.map(& &1.related_to)
      |> Enum.reject(&(&1 == "" or &1 == nil))
      |> Enum.uniq()

    if related_names == [] do
      {:ok, []}
    else
      cypher = """
      MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e:Entity)
      WHERE e.name IN $names
      RETURN e.name as name, e.type as type, e.properties as properties
      """

      case Memgraph.query(cypher, %{graph_id: graph_id, names: related_names}) do
        {:ok, entities} -> {:ok, entities}
        error -> error
      end
    end
  end

  defp build_entity_context(entity, relations, related_entities) do
    parts = []

    if entity && entity["properties"] do
      props =
        case entity["properties"] do
          properties when is_binary(properties) ->
            case Jason.decode(properties) do
              {:ok, p} -> p
              _ -> %{}
            end

          p when is_map(p) ->
            p

          _ ->
            %{}
        end

      if props != %{} do
        attr_parts =
          props
          |> Enum.reject(fn {_, v} -> v == nil or v == "" end)
          |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)

        if attr_parts != [] do
          parts = parts ++ ["## Attributes\n" <> String.join(attr_parts, "\n")]
        end
      end
    end

    if relations && relations != [] do
      relation_parts =
        relations
        |> Enum.reject(&(&1.fact == "" or &1.fact == nil))
        |> Enum.map(fn r ->
          case r.direction do
            :outgoing -> "#{entity["name"]} --[#{r.type}]--> #{r.related_to}"
            :incoming -> "#{r.related_to} --[#{r.type}]--> #{entity["name"]}"
          end
        end)

      if relation_parts != [] do
        parts = parts ++ ["## Relations\n" <> String.join(relation_parts, "\n")]
      end
    end

    if related_entities && related_entities != [] do
      entity_parts =
        related_entities
        |> Enum.map(fn re ->
          type_str = if re["type"], do: " (#{re["type"]})", else: ""
          name_str = if re["name"], do: re["name"], else: ""
          "#{name_str}#{type_str}"
        end)

      if entity_parts != [] do
        parts = parts ++ ["## Related Entities\n" <> String.join(entity_parts, "\n")]
      end
    end

    Enum.join(parts, "\n\n")
  end
end
