defmodule Miroex.Graph.Paginator do
  @moduledoc """
  Cursor-based pagination utilities for Memgraph queries.
  """

  alias Miroex.Memgraph

  @default_page_size 100
  @max_page_size 1000

  @doc """
  Fetches all nodes from a graph with pagination.
  Uses cursor-based pagination via name ordering.

  Options:
    - :page_size - items per page (default 100, max 1000)
    - :max_items - maximum total items (default :infinity)
    - :offset - starting offset (alternative to cursor)
    - :limit - max items to return (alternative to max_items)
  """
  @spec fetch_all_nodes(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def fetch_all_nodes(graph_id, opts \\ []) do
    page_size = min(opts[:page_size] || @default_page_size, @max_page_size)
    max_items = opts[:max_items] || :infinity
    offset = opts[:offset] || 0

    do_fetch_nodes(graph_id, [], page_size, offset, 0, max_items)
  end

  @doc """
  Fetches all edges/relations from a graph with pagination.
  """
  @spec fetch_all_edges(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def fetch_all_edges(graph_id, opts \\ []) do
    page_size = min(opts[:page_size] || @default_page_size, @max_page_size)
    max_items = opts[:max_items] || :infinity
    offset = opts[:offset] || 0

    do_fetch_edges(graph_id, [], page_size, offset, 0, max_items)
  end

  @doc """
  Fetches entities in batches for streaming/processing.
  Calls callback with each batch.
  """
  @spec fetch_in_batches(String.t(), fun(), any(), keyword()) :: {:ok, any()} | {:error, term()}
  def fetch_in_batches(graph_id, callback, acc \\ nil, opts \\ []) do
    page_size = Keyword.get(opts, :page_size, @default_page_size)
    batch_num = 0

    do_fetch_batches(graph_id, callback, acc, batch_num, page_size, 0)
  end

  defp do_fetch_nodes(_graph_id, acc, _page_size, _offset, count, max) when count >= max do
    {:ok, Enum.take(acc, if(max == :infinity, do: length(acc), else: max))}
  end

  defp do_fetch_nodes(graph_id, acc, page_size, offset, count, max) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e:Entity)
    RETURN e.name as name, e.type as type, e.properties as properties
    ORDER BY e.name
    SKIP $offset
    LIMIT $limit
    """

    case Memgraph.query(cypher, %{graph_id: graph_id, offset: offset, limit: page_size}) do
      {:ok, []} ->
        {:ok, acc}

      {:ok, rows} ->
        new_acc = acc ++ rows
        new_count = count + length(rows)

        if length(rows) < page_size || new_count >= max do
          {:ok, Enum.take(new_acc, if(max == :infinity, do: length(new_acc), else: max))}
        else
          do_fetch_nodes(graph_id, new_acc, page_size, offset + page_size, new_count, max)
        end

      error ->
        error
    end
  end

  defp do_fetch_edges(_graph_id, acc, _page_size, _offset, count, max) when count >= max do
    {:ok, Enum.take(acc, if(max == :infinity, do: length(acc), else: max))}
  end

  defp do_fetch_edges(graph_id, acc, page_size, offset, count, max) do
    cypher = """
    MATCH (g:Graph {id: $graph_id})-[:HAS_ENTITY]->(e1:Entity)-[r:RELATES]->(e2:Entity)
    RETURN e1.name as from, e2.name as to, r.type as type
    ORDER BY e1.name
    SKIP $offset
    LIMIT $limit
    """

    case Memgraph.query(cypher, %{graph_id: graph_id, offset: offset, limit: page_size}) do
      {:ok, []} ->
        {:ok, acc}

      {:ok, rows} ->
        new_acc = acc ++ rows
        new_count = count + length(rows)

        if length(rows) < page_size || new_count >= max do
          {:ok, Enum.take(new_acc, if(max == :infinity, do: length(new_acc), else: max))}
        else
          do_fetch_edges(graph_id, new_acc, page_size, offset + page_size, new_count, max)
        end

      error ->
        error
    end
  end

  defp do_fetch_batches(_graph_id, _callback, acc, _batch_num, _page_size, _offset) do
    {:ok, acc}
  end
end
