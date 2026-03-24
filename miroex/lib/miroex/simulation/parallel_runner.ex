defmodule Miroex.Simulation.ParallelRunner do
  @moduledoc """
  Parallel simulation runner for dual-platform simulations.

  Runs both Twitter and Reddit simulations simultaneously, coordinating
  agent actions and aggregating results.

  ## Usage

      {:ok, runner_pid} = ParallelRunner.start_link(
        simulation_id: "sim_123",
        graph_id: "graph_456",
        config: config
      )

      ParallelRunner.start_parallel_simulation(runner_pid)

  """

  use GenServer

  alias Miroex.Simulation.Orchestrator

  @type platform_config :: %{
          platform: :twitter | :reddit,
          agent_count: non_neg_integer(),
          rounds: non_neg_integer(),
          round_interval: non_neg_integer()
        }

  @type parallel_state :: %{
          simulation_id: String.t(),
          graph_id: String.t(),
          config: map(),
          twitter_orchestrator: pid() | nil,
          reddit_orchestrator: pid() | nil,
          status: :idle | :running | :paused | :completed | :failed,
          round: non_neg_integer(),
          total_rounds: non_neg_integer(),
          start_time: DateTime.t() | nil,
          aggregated_actions: [map()]
        }

  # Client API

  @doc """
  Starts the parallel runner GenServer.

  ## Options
    - :simulation_id - Required. The simulation ID
    - :graph_id - Required. The graph ID
    - :config - Required. Simulation configuration
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    simulation_id = Keyword.fetch!(opts, :simulation_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(simulation_id))
  end

  @doc """
  Starts the parallel simulation on both platforms.
  """
  @spec start_parallel_simulation(pid()) :: :ok
  def start_parallel_simulation(pid) do
    GenServer.cast(pid, :start_simulation)
  end

  @doc """
  Pauses the parallel simulation.
  """
  @spec pause_simulation(pid()) :: :ok
  def pause_simulation(pid) do
    GenServer.cast(pid, :pause)
  end

  @doc """
  Resumes the parallel simulation.
  """
  @spec resume_simulation(pid()) :: :ok
  def resume_simulation(pid) do
    GenServer.cast(pid, :resume)
  end

  @doc """
  Stops the parallel simulation.
  """
  @spec stop_simulation(pid()) :: :ok
  def stop_simulation(pid) do
    GenServer.cast(pid, :stop)
  end

  @doc """
  Gets the combined status from both platforms.
  """
  @spec get_combined_status(pid()) :: map()
  def get_combined_status(pid) do
    GenServer.call(pid, :get_status, 30_000)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    simulation_id = Keyword.fetch!(opts, :simulation_id)
    graph_id = Keyword.fetch!(opts, :graph_id)
    config = Keyword.fetch!(opts, :config)

    state = %{
      simulation_id: simulation_id,
      graph_id: graph_id,
      config: config,
      twitter_orchestrator: nil,
      reddit_orchestrator: nil,
      status: :idle,
      round: 0,
      total_rounds: config[:rounds] || 100,
      start_time: nil,
      aggregated_actions: []
    }

    {:ok, state}
  end

  @impl true
  def handle_cast(:start_simulation, %{status: :idle} = state) do
    # Start both orchestrators in parallel
    twitter_task = Task.async(fn -> start_platform_orchestrator(state, :twitter) end)
    reddit_task = Task.async(fn -> start_platform_orchestrator(state, :reddit) end)

    # Wait for both to start
    twitter_result = Task.await(twitter_task, 30_000)
    reddit_result = Task.await(reddit_task, 30_000)

    new_state =
      case {twitter_result, reddit_result} do
        {{:ok, twitter_pid}, {:ok, reddit_pid}} ->
          # Start both simulations
          Orchestrator.start_simulation(twitter_pid)
          Orchestrator.start_simulation(reddit_pid)

          schedule_next_round()

          %{
            state
            | twitter_orchestrator: twitter_pid,
              reddit_orchestrator: reddit_pid,
              status: :running,
              start_time: DateTime.utc_now()
          }

        {{:error, _reason}, _} ->
          %{state | status: :failed}

        {_, {:error, _reason}} ->
          %{state | status: :failed}
      end

    {:noreply, new_state}
  end

  def handle_cast(:start_simulation, state) do
    # Already running or completed
    {:noreply, state}
  end

  @impl true
  def handle_cast(:pause, %{status: :running} = state) do
    # Pause both orchestrators
    if state.twitter_orchestrator do
      Orchestrator.pause(state.twitter_orchestrator)
    end

    if state.reddit_orchestrator do
      Orchestrator.pause(state.reddit_orchestrator)
    end

    {:noreply, %{state | status: :paused}}
  end

  def handle_cast(:pause, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:resume, %{status: :paused} = state) do
    # Resume both orchestrators
    if state.twitter_orchestrator do
      Orchestrator.resume(state.twitter_orchestrator)
    end

    if state.reddit_orchestrator do
      Orchestrator.resume(state.reddit_orchestrator)
    end

    schedule_next_round()

    {:noreply, %{state | status: :running}}
  end

  def handle_cast(:resume, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:stop, state) do
    # Stop both orchestrators
    if state.twitter_orchestrator do
      Orchestrator.stop(state.twitter_orchestrator)
    end

    if state.reddit_orchestrator do
      Orchestrator.stop(state.reddit_orchestrator)
    end

    {:noreply, %{state | status: :completed}}
  end

  @impl true
  def handle_info(:run_round, %{status: :running, round: round, total_rounds: total} = state)
      when round < total do
    # Execute one round on both platforms
    twitter_actions = execute_round(state.twitter_orchestrator, :twitter)
    reddit_actions = execute_round(state.reddit_orchestrator, :reddit)

    # Aggregate actions
    new_actions = twitter_actions ++ reddit_actions

    # Cross-platform coordination (agents can see posts from other platform)
    coordinated_actions = coordinate_cross_platform(state, new_actions)

    new_state = %{
      state
      | round: round + 1,
        aggregated_actions: state.aggregated_actions ++ coordinated_actions
    }

    # Continue to next round if still running
    if new_state.round < total and new_state.status == :running do
      schedule_next_round()
    else
      # Simulation complete
      GenServer.cast(self(), :stop)
    end

    {:noreply, new_state}
  end

  def handle_info(:run_round, state) do
    # Simulation complete or not running
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    # Get status from both orchestrators
    twitter_status = get_orchestrator_status(state.twitter_orchestrator)
    reddit_status = get_orchestrator_status(state.reddit_orchestrator)

    combined_status = %{
      simulation_id: state.simulation_id,
      status: state.status,
      round: state.round,
      total_rounds: state.total_rounds,
      start_time: state.start_time,
      elapsed_time: calculate_elapsed(state.start_time),
      platforms: %{
        twitter: twitter_status,
        reddit: reddit_status
      },
      total_actions: length(state.aggregated_actions),
      actions_by_platform: %{
        twitter: count_actions_by_platform(state.aggregated_actions, :twitter),
        reddit: count_actions_by_platform(state.aggregated_actions, :reddit)
      }
    }

    {:reply, combined_status, state}
  end

  # Private functions

  defp via_tuple(simulation_id) do
    {:via, Registry, {Miroex.Simulation.AgentRegistry, {:parallel_runner, simulation_id}}}
  end

  defp start_platform_orchestrator(state, platform) do
    platform_config =
      state.config
      |> Map.put(:platform, platform)
      |> Map.put(:simulation_id, "#{state.simulation_id}_#{platform}")

    orchestrator_name = String.to_atom("orchestrator_#{state.simulation_id}_#{platform}")

    Orchestrator.start_link(
      simulation_id: "#{state.simulation_id}_#{platform}",
      graph_id: state.graph_id,
      config: platform_config,
      name: orchestrator_name
    )
  end

  defp schedule_next_round do
    # Run rounds every 5 seconds
    Process.send_after(self(), :run_round, 5_000)
  end

  defp execute_round(nil, _platform), do: []

  defp execute_round(orchestrator_pid, platform) do
    # Execute one round and get actions
    case Orchestrator.execute_round(orchestrator_pid) do
      {:ok, actions} ->
        Enum.map(actions, fn action ->
          Map.put(action, :platform, platform)
        end)

      _ ->
        []
    end
  end

  defp coordinate_cross_platform(state, actions) do
    # Simple coordination: agents can see mentions of posts from other platforms
    # In a full implementation, this would allow agents to reference cross-platform
    # For now, just track that cross-platform interaction happened

    Enum.map(actions, fn action ->
      mentions_other = detect_cross_platform_mention(action, state.aggregated_actions)
      Map.put(action, :cross_platform, mentions_other)
    end)
  end

  defp detect_cross_platform_mention(_action, []), do: false

  defp detect_cross_platform_mention(action, previous_actions) do
    # Check if the action content mentions any entity from previous cross-platform posts
    content = Map.get(action, :content, "")

    Enum.any?(previous_actions, fn prev ->
      prev_platform = Map.get(prev, :platform)
      action_platform = Map.get(action, :platform)

      if prev_platform != action_platform do
        # Check if content mentions the other agent
        prev_agent = Map.get(prev, :agent_name, "")
        String.contains?(content, prev_agent)
      else
        false
      end
    end)
  end

  defp get_orchestrator_status(nil) do
    %{status: :not_started, agent_count: 0, actions_count: 0}
  end

  defp get_orchestrator_status(orchestrator_pid) do
    try do
      Orchestrator.get_state(orchestrator_pid)
    catch
      _, _ ->
        %{status: :unknown, agent_count: 0, actions_count: 0}
    end
  end

  defp calculate_elapsed(nil), do: 0

  defp calculate_elapsed(start_time) do
    DateTime.diff(DateTime.utc_now(), start_time, :second)
  end

  defp count_actions_by_platform(actions, platform) do
    Enum.count(actions, fn action ->
      Map.get(action, :platform) == platform
    end)
  end
end
