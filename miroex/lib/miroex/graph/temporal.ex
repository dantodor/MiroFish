defmodule Miroex.Graph.Temporal do
  @moduledoc """
  Temporal fact management for graph edges.

  Provides application-level support for tracking fact validity over time.
  Each edge (fact) can have temporal properties:
  - created_at: when the fact was first created
  - valid_at: when the fact becomes valid (can be same as created_at)
  - invalid_at: when the fact becomes invalid (nil = still valid)
  - expired_at: when the fact is no longer relevant

  This enables tracking of evolving facts and historical states.
  """

  @type temporal_edge :: %{
          from: String.t(),
          to: String.t(),
          type: String.t(),
          fact: String.t(),
          created_at: DateTime.t(),
          valid_at: DateTime.t(),
          invalid_at: DateTime.t() | nil,
          expired_at: DateTime.t() | nil
        }

  @doc """
  Creates temporal edge data with default timestamps.

  ## Parameters
    - from: Source entity name
    - to: Target entity name
    - type: Relationship type
    - fact: The fact description
    - valid_from: When the fact becomes valid (defaults to now)

  ## Returns
    temporal_edge map
  """
  @spec create_edge(String.t(), String.t(), String.t(), String.t(), DateTime.t() | nil) ::
          temporal_edge()
  def create_edge(from, to, type, fact, valid_from \\ nil) do
    now = valid_from || DateTime.utc_now()

    %{
      from: from,
      to: to,
      type: type,
      fact: fact,
      created_at: now,
      valid_at: now,
      invalid_at: nil,
      expired_at: nil
    }
  end

  @doc """
  Marks a temporal edge as invalid at the current time.

  ## Parameters
    - edge: The temporal edge map

  ## Returns
    Updated edge with invalid_at set to now
  """
  @spec invalidate(temporal_edge()) :: temporal_edge()
  def invalidate(edge) do
    Map.put(edge, :invalid_at, DateTime.utc_now())
  end

  @doc """
  Marks a temporal edge as expired at the current time.

  ## Parameters
    - edge: The temporal edge map

  ## Returns
    Updated edge with expired_at set to now
  """
  @spec expire(temporal_edge()) :: temporal_edge()
  def expire(edge) do
    Map.put(edge, :expired_at, DateTime.utc_now())
  end

  @doc """
  Updates the validity period of a temporal edge.

  ## Parameters
    - edge: The temporal edge map
    - valid_at: New valid from datetime
    - invalid_at: New invalid at datetime (nil = still valid)

  ## Returns
    Updated edge with new validity period
  """
  @spec set_validity(temporal_edge(), DateTime.t(), DateTime.t() | nil) :: temporal_edge()
  def set_validity(edge, valid_at, invalid_at) do
    edge
    |> Map.put(:valid_at, valid_at)
    |> Map.put(:invalid_at, invalid_at)
  end

  @doc """
  Checks if a temporal edge is currently valid.

  ## Parameters
    - edge: The temporal edge map

  ## Returns
    boolean
  """
  @spec valid?(temporal_edge()) :: boolean()
  def valid?(edge) do
    is_nil(edge[:invalid_at])
  end

  @doc """
  Checks if a temporal edge has expired.

  ## Parameters
    - edge: The temporal edge map

  ## Returns
    boolean
  """
  @spec expired?(temporal_edge()) :: boolean()
  def expired?(edge) do
    not is_nil(edge[:expired_at])
  end

  @doc """
  Checks if a temporal edge was valid at a specific point in time.

  ## Parameters
    - edge: The temporal edge map
    - datetime: The datetime to check

  ## Returns
    boolean
  """
  @spec valid_at?(temporal_edge(), DateTime.t()) :: boolean()
  def valid_at?(edge, datetime) do
    valid_start = edge[:valid_at]
    valid_end = edge[:invalid_at]

    after_start = DateTime.compare(datetime, valid_start) in [:gt, :eq]
    before_end = is_nil(valid_end) or DateTime.compare(datetime, valid_end) == :lt

    after_start and before_end
  end

  @doc """
  Filters a list of temporal edges to get only currently valid ones.

  ## Parameters
    - edges: List of temporal edge maps

  ## Returns
    List of valid edges
  """
  @spec filter_valid([temporal_edge()]) :: [temporal_edge()]
  def filter_valid(edges) do
    Enum.filter(edges, &valid?/1)
  end

  @doc """
  Filters a list of temporal edges to get only expired/invalid ones.

  ## Parameters
    - edges: List of temporal edge maps

  ## Returns
    List of expired edges
  """
  @spec filter_expired([temporal_edge()]) :: [temporal_edge()]
  def filter_expired(edges) do
    Enum.filter(edges, &expired?/1)
  end

  @doc """
  Filters temporal edges to get ones that were valid at a specific time.

  ## Parameters
    - edges: List of temporal edge maps
    - datetime: The datetime to check

  ## Returns
    List of edges valid at that time
  """
  @spec filter_valid_at([temporal_edge()], DateTime.t()) :: [temporal_edge()]
  def filter_valid_at(edges, datetime) do
    Enum.filter(edges, fn edge -> valid_at?(edge, datetime) end)
  end

  @doc """
  Groups temporal edges by their current validity status.

  ## Parameters
    - edges: List of temporal edge maps

  ## Returns
    %{valid: [...], expired: [...], invalid: [...]}
  """
  @spec group_by_status([temporal_edge()]) :: %{
          valid: [temporal_edge()],
          expired: [temporal_edge()],
          invalid: [temporal_edge()]
        }
  def group_by_status(edges) do
    edges
    |> Enum.group_by(fn edge ->
      cond do
        expired?(edge) -> :expired
        not valid?(edge) -> :invalid
        true -> :valid
      end
    end)
    |> Map.put_new(:valid, [])
    |> Map.put_new(:expired, [])
    |> Map.put_new(:invalid, [])
  end

  @doc """
  Converts temporal edge data to a format suitable for Memgraph storage.

  ## Parameters
    - edge: The temporal edge map

  ## Returns
    Map with string keys for Memgraph
  """
  @spec to_memgraph_props(temporal_edge()) :: map()
  def to_memgraph_props(edge) do
    %{
      "type" => edge.type,
      "fact" => edge.fact,
      "created_at" => DateTime.to_iso8601(edge.created_at),
      "valid_at" => DateTime.to_iso8601(edge.valid_at),
      "invalid_at" => if(edge.invalid_at, do: DateTime.to_iso8601(edge.invalid_at), else: nil),
      "expired_at" => if(edge.expired_at, do: DateTime.to_iso8601(edge.expired_at), else: nil)
    }
  end

  @doc """
  Parses temporal edge data from Memgraph query results.

  ## Parameters
    - props: Map from Memgraph with string keys

  ## Returns
    temporal_edge map
  """
  @spec from_memgraph_props(map()) :: temporal_edge()
  def from_memgraph_props(props) do
    %{
      from: props["from"] || "",
      to: props["to"] || "",
      type: props["type"] || "",
      fact: props["fact"] || "",
      created_at: parse_datetime(props["created_at"]),
      valid_at: parse_datetime(props["valid_at"]),
      invalid_at: parse_datetime(props["invalid_at"]),
      expired_at: parse_datetime(props["expired_at"])
    }
  end

  @doc """
  Formats a temporal edge for display in reports or logs.

  ## Parameters
    - edge: The temporal edge map
    - include_temporal: Whether to include temporal info (default: true)

  ## Returns
    String representation
  """
  @spec format(temporal_edge(), boolean()) :: String.t()
  def format(edge, include_temporal \\ true) do
    base = "#{edge.from} --[#{edge.type}]--> #{edge.to}: #{edge.fact}"

    if include_temporal do
      valid_str = DateTime.to_iso8601(edge.valid_at)
      invalid_str = if edge.invalid_at, do: DateTime.to_iso8601(edge.invalid_at), else: "present"
      status = if valid?(edge), do: "VALID", else: "INVALID"

      "#{base}\n  Valid: #{valid_str} to #{invalid_str} [#{status}]"
    else
      base
    end
  end

  # Private functions

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_str) when is_binary(datetime_str) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(%DateTime{} = datetime), do: datetime
  defp parse_datetime(_), do: nil
end
