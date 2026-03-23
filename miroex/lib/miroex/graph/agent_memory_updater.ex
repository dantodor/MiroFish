defmodule Miroex.Graph.AgentMemoryUpdater do
  @moduledoc """
  GenServer that batches and persists agent activities to Memgraph.

  Uses a separate Memgraph connection dedicated to memory updates.
  Activities are queued and flushed in batches for efficiency.
  """

  use GenServer, restart: :permanent

  alias Miroex.Graph.AgentMemoryUpdater.MemgraphClient

  @default_max_queue_size 50
  @default_flush_interval 5_000

  @doc """
  Start the memory updater GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Add an activity to the queue. The activity will be persisted
  to Memgraph either when the queue reaches max size or after
  the flush interval.
  """
  @spec add_activity(map(), GenServer.server()) :: :ok
  def add_activity(activity, server \\ __MODULE__) when is_map(activity) do
    GenServer.cast(server, {:add_activity, activity})
  end

  @doc """
  Force a flush of all queued activities to Memgraph.
  """
  @spec flush(GenServer.server()) :: :ok | {:error, term()}
  def flush(server \\ __MODULE__) do
    GenServer.call(server, :flush, 30_000)
  end

  @doc """
  Get the current queue size without flushing.
  """
  @spec queue_size(GenServer.server()) :: non_neg_integer()
  def queue_size(server \\ __MODULE__) do
    GenServer.call(server, :queue_size)
  end

  @doc """
  Stop the memory updater, flushing any remaining activities first.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(server \\ __MODULE__) do
    GenServer.cast(server, :stop)
  end

  @impl true
  def init(opts) do
    max_queue_size = Keyword.get(opts, :max_queue_size, @default_max_queue_size)
    flush_interval = Keyword.get(opts, :flush_interval, @default_flush_interval)

    state = %{
      queue: [],
      max_queue_size: max_queue_size,
      flush_interval: flush_interval,
      flush_timer: nil
    }

    new_state = schedule_flush(state)
    {:ok, new_state}
  end

  @impl true
  def handle_cast({:add_activity, activity}, state) do
    new_queue = [activity | state.queue]

    if length(new_queue) >= state.max_queue_size do
      case do_flush(new_queue) do
        :ok ->
          new_state = %{state | queue: [], flush_timer: cancel_timer(state.flush_timer)}
          {:noreply, new_state, :hibernate}

        {:error, _reason} ->
          new_state = %{state | queue: new_queue}
          {:noreply, new_state, :hibernate}
      end
    else
      {:noreply, %{state | queue: new_queue}, :hibernate}
    end
  end

  @impl true
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    case do_flush(state.queue) do
      :ok ->
        {:reply, :ok, %{state | queue: [], flush_timer: cancel_timer(state.flush_timer)}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:queue_size, _from, state) do
    {:reply, length(state.queue), state}
  end

  @impl true
  def handle_info(:flush, state) do
    case do_flush(state.queue) do
      :ok ->
        new_state = schedule_flush(%{state | queue: []})
        {:noreply, new_state}

      {:error, _reason} ->
        new_state = schedule_flush(state)
        {:noreply, new_state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    if length(state.queue) > 0 do
      do_flush(state.queue)
    end

    :ok
  end

  defp schedule_flush(state) do
    timer = Process.send_after(self(), :flush, state.flush_interval)
    %{state | flush_timer: timer}
  end

  defp cancel_timer(nil), do: nil

  defp cancel_timer(timer) do
    Process.cancel_timer(timer)
    nil
  end

  defp do_flush([]), do: :ok

  defp do_flush(activities) do
    activities
    |> Enum.reverse()
    |> Enum.chunk_every(50)
    |> Enum.reduce_while(:ok, fn batch, :ok ->
      case persist_batch(batch) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp persist_batch(activities) when is_list(activities) do
    queries =
      Enum.map(activities, fn activity ->
        cypher = """
        MATCH (g:Graph {id: $graph_id})
        MERGE (a:Agent {agent_id: $agent_id, graph_id: $graph_id})
        MERGE (g)-[:HAS_AGENT]->(a)
        CREATE (a)-[:PERFORMED]->(exp:Experience {
          action_type: $action_type,
          content: $content,
          round: $round,
          timestamp: datetime($timestamp),
          metadata: $metadata
        })
        RETURN exp.id as id
        """

        %{
          query: cypher,
          params: %{
            graph_id: activity[:graph_id] || "",
            agent_id: activity[:agent_id] || 0,
            action_type: activity[:action_type] || "unknown",
            content: activity[:content] || "",
            round: activity[:round] || 0,
            timestamp: activity[:timestamp] || DateTime.utc_now() |> DateTime.to_iso8601(),
            metadata: Jason.encode!(activity[:metadata] || %{})
          }
        }
      end)

    MemgraphClient.transaction(queries)
  end
end
