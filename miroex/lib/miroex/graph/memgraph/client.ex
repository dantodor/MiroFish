defmodule Miroex.Memgraph.Client do
  @moduledoc false

  def query(cypher, params \\ %{}) do
    url = memgraph_url() <> "/api/v1/query"

    body = %{
      query: cypher,
      params: params
    }

    headers = [
      {"Content-Type", "application/json"}
    ]

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

  def transaction(queries) when is_list(queries) do
    url = memgraph_url() <> "/api/v1 transaction"

    transaction_body = %{
      statements:
        Enum.map(queries, fn {cypher, params} ->
          %{query: cypher, params: params || %{}}
        end)
    }

    headers = [
      {"Content-Type", "application/json"}
    ]

    case Req.post(url, json: transaction_body, headers: headers) do
      {:ok, %{status: 200, body: %{"results" => results}}} ->
        {:ok, Enum.map(results, &parse_results/1)}

      {:ok, %{status: status, body: %{"errors" => errors}}} ->
        {:error, {:transaction_error, status, errors}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def ping do
    url = memgraph_url() <> "/api/v1 ping"

    case Req.get(url) do
      {:ok, %{status: 200}} -> :ok
      error -> error
    end
  end

  defp memgraph_url do
    Application.get_env(:miroex, :memgraph)[:url] || "http://localhost:7444"
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
