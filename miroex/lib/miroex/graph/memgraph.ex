defmodule Miroex.Memgraph do
  @moduledoc """
  Memgraph client using HTTP API (GQL endpoint on port 7444).
  """
  alias Miroex.Memgraph.Client

  @doc """
  Execute a Cypher query against Memgraph via HTTP.
  """
  @spec query(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def query(cypher, params \\ %{}) do
    Client.query(cypher, params)
  end

  @doc """
  Execute multiple queries in a transaction.
  """
  @spec transaction([{String.t(), map()}]) :: {:ok, [term()]} | {:error, term()}
  def transaction(queries) when is_list(queries) do
    Client.transaction(queries)
  end

  @doc """
  Check if Memgraph is connected.
  """
  @spec ping() :: :ok | {:error, term()}
  def ping do
    Client.ping()
  end
end
