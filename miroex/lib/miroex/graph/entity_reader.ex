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
    RETURN e1.name as from, e2.name as to, r.type as type
    """

    case Memgraph.query(cypher, %{graph_id: graph_id}) do
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
end
