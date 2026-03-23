defmodule Miroex.AI.Openrouter do
  @moduledoc """
  OpenRouter AI client using Req.
  """
  use GenServer
  alias Miroex.AI.Openrouter.Client

  @spec chat(map()) :: {:ok, map()} | {:error, term()}
  def chat(messages, model \\ "openai/gpt-4o-mini") do
    GenServer.call(__MODULE__, {:chat, messages, model}, 60_000)
  end

  @spec chat_stream(map(), pid()) :: :ok | {:error, term()}
  def chat_stream(messages, caller_pid, model \\ "openai/gpt-4o-mini") do
    GenServer.cast(__MODULE__, {:chat_stream, messages, caller_pid, model})
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      api_key: Application.get_env(:miroex, :openrouter)[:api_key],
      base_url:
        Application.get_env(:miroex, :openrouter)[:base_url] || "https://openrouter.ai/api/v1"
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:chat, messages, model}, _from, state) do
    result = Client.chat(state.api_key, state.base_url, messages, model)
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:chat_stream, messages, caller_pid, model}, state) do
    Client.chat_stream(state.api_key, state.base_url, messages, model, caller_pid)
    {:noreply, state}
  end
end
