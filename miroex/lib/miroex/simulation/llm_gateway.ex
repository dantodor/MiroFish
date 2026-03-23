defmodule Miroex.Simulation.LLMGateway do
  @moduledoc """
  Rate-limited LLM gateway using NimblePool.
  """
  use GenServer
  alias Miroex.AI.Openrouter

  @name __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  def request(messages, model \\ "openai/gpt-4o-mini") do
    GenServer.call(@name, {:request, messages, model}, 120_000)
  end

  @impl true
  def init(_opts) do
    state = %{
      max_concurrent: Application.get_env(:miroex, :llm_gateway)[:max_concurrent_requests] || 10,
      rps: Application.get_env(:miroex, :llm_gateway)[:requests_per_second] || 5,
      current_requests: 0,
      last_request_time: 0,
      queue: :queue.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:request, messages, model}, from, state) do
    if state.current_requests < state.max_concurrent do
      {:noreply, state} =
        do_process_request(messages, model, from, %{
          state
          | current_requests: state.current_requests + 1
        })

      {:noreply, %{state | current_requests: state.current_requests + 1}}
    else
      queue = :queue.in({messages, model, from}, state.queue)
      {:noreply, %{state | queue: queue}}
    end
  end

  @impl true
  def handle_info(:process_queue, state) do
    case :queue.out(state.queue) do
      {{:value, {messages, model, from}}, queue} ->
        do_process_request(messages, model, from, %{state | queue: queue})
        {:noreply, state}

      {:empty, _queue} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:request_complete, _from}, state) do
    new_state = %{state | current_requests: max(0, state.current_requests - 1)}
    Process.send_after(self(), :process_queue, 100)
    {:noreply, new_state}
  end

  defp do_process_request(messages, model, from, state) do
    spawn(fn ->
      result = Openrouter.chat(messages, model)
      GenServer.reply(from, result)
      send(self(), {:request_complete, from})
    end)

    {:noreply, state}
  end
end
