defmodule Miroex.Graph.AgentMemoryUpdater.MemgraphClient do
  @moduledoc """
  Dedicated Memgraph HTTP client for AgentMemoryUpdater.
  Uses its own connection to avoid contention with main Memgraph client.
  """

  @doc """
  Execute a single Cypher query against Memgraph.
  """
  @spec query(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def query(cypher, params \\ %{}) do
    url = memgraph_url() <> "/api/v1/query"

    body = %{
      query: cypher,
      params: params
    }

    headers = [{"Content-Type", "application/json"}]

    case Req.post(url, json: body, headers: headers) do
      {:ok, %{status: 200, body: %{"results" => results}}} ->
        {:ok, parse_results(results)}

      {:ok, %{status: status, body: %{"errors" => errors}}} ->
        {:error, {:query_error, status, errors}}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Execute multiple queries in a transaction using Memgraph's transaction API.
  """
  @spec transaction([%{query: String.t(), params: map()}]) :: {:ok, [term()]} | {:error, term()}
  def transaction(queries) when is_list(queries) do
    url = memgraph_url() <> "/api/v1/transactions/begin"

    transaction_body = %{
      statements:
        Enum.map(queries, fn %{query: cypher, params: params} ->
          %{query: cypher, params: params || %{}}
        end)
    }

    headers = [{"Content-Type", "application/json"}]

    with {:ok, %{body: %{"transaction_id" => txn_id}}} <-
           Req.post(url, json: transaction_body, headers: headers),
         {:ok, _} <- commit_transaction(txn_id, queries) do
      {:ok, []}
    else
      {:ok, %{body: %{"errors" => errors}}} ->
        {:error, {:transaction_error, errors}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp commit_transaction(txn_id, queries) do
    commit_url = memgraph_url() <> "/api/v1/transactions/#{txn_id}/commit"

    body = %{
      statements:
        Enum.map(queries, fn %{query: cypher, params: params} ->
          %{query: cypher, params: params || %{}}
        end)
    }

    headers = [{"Content-Type", "application/json"}]
    Req.post(commit_url, json: body, headers: headers)
  end

  @doc """
  Check if Memgraph is connected.
  """
  @spec ping() :: :ok | {:error, term()}
  def ping do
    url = memgraph_url() <> "/api/v1/ping"

    case Req.get(url) do
      {:ok, %{status: 200}} -> :ok
      error -> error
    end
  end

  defp memgraph_url do
    Application.get_env(:miroex, :memory_updater_memgraph)[:url] ||
      Application.get_env(:miroex, :memgraph)[:url] ||
      "http://localhost:7444"
  end

  defp parse_results(results) when is_list(results) do
    Enum.map(results, &parse_result/1)
  end

  defp parse_results(result), do: parse_result(result)

  defp parse_result(%{"columns" => columns, "data" => rows}) do
    Enum.map(rows, fn row ->
      Enum.zip(columns, row) |> Map.new()
    end)
  end

  defp parse_result(other), do: other
end
