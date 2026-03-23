defmodule Miroex.Simulation.Orchestrator do
  @moduledoc """
  Orchestrates the simulation - coordinates agents, environments, and rounds.
  """
  use GenServer
  require Logger

  alias Miroex.Simulation.{Agent, AgentRegistry, AgentSupervisor, Environment, StateManager}
  alias Miroex.Graph.AgentMemoryUpdater

  defstruct [
    :simulation_id,
    :project_id,
    :user_id,
    :config,
    :current_round,
    :total_rounds,
    :twitter_env_pid,
    :reddit_env_pid,
    :agent_pids,
    :memory_updater_pid,
    :status
  ]

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      simulation_id: Keyword.fetch!(opts, :simulation_id),
      project_id: Keyword.fetch!(opts, :project_id),
      user_id: Keyword.fetch!(opts, :user_id),
      config: Keyword.get(opts, :config, %{}),
      current_round: 0,
      total_rounds: 72,
      twitter_env_pid: nil,
      reddit_env_pid: nil,
      agent_pids: [],
      memory_updater_pid: nil,
      status: :initialized
    }

    {:ok, state}
  end

  def prepare_simulation(orch_pid, graph_id, enable_twitter, enable_reddit) do
    GenServer.call(orch_pid, {:prepare, graph_id, enable_twitter, enable_reddit})
  end

  def start_simulation(orch_pid), do: GenServer.cast(orch_pid, :start_simulation)
  def pause_simulation(orch_pid), do: GenServer.cast(orch_pid, :pause_simulation)
  def resume_simulation(orch_pid), do: GenServer.cast(orch_pid, :resume_simulation)
  def stop_simulation(orch_pid), do: GenServer.cast(orch_pid, :stop_simulation)
  def get_status(orch_pid), do: GenServer.call(orch_pid, :get_status)

  def interview_agent(orch_pid, agent_id, question) do
    GenServer.call(orch_pid, {:interview_agent, agent_id, question})
  end

  @impl true
  def handle_call({:prepare, graph_id, enable_twitter, enable_reddit}, _from, state) do
    Logger.info("Preparing simulation #{state.simulation_id}")

    twitter_env =
      if enable_twitter do
        {:ok, pid} =
          Environment.start_link(%{platform: :twitter, simulation_id: state.simulation_id})

        pid
      end

    reddit_env =
      if enable_reddit do
        {:ok, pid} =
          Environment.start_link(%{platform: :reddit, simulation_id: state.simulation_id})

        pid
      end

    agents = spawn_agents(graph_id, state.simulation_id, state.config)

    {:ok, memory_pid} =
      AgentMemoryUpdater.start_link(name: String.to_atom("memory_updater_#{state.simulation_id}"))

    new_state = %{
      state
      | twitter_env_pid: twitter_env,
        reddit_env_pid: reddit_env,
        agent_pids: agents,
        memory_updater_pid: memory_pid,
        status: :ready
    }

    {:reply, {:ok, %{agents_count: length(agents)}}, new_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:interview_agent, agent_id, question}, _from, state) do
    case AgentRegistry.lookup(state.simulation_id, agent_id) do
      {:ok, agent_pid} ->
        result = Agent.interview(agent_pid, question)
        {:reply, result, state}

      :error ->
        {:reply, {:error, :agent_not_found}, state}
    end
  end

  @impl true
  def handle_cast(:start_simulation, state) do
    Logger.info("Starting simulation #{state.simulation_id}")
    schedule_next_round()
    {:noreply, %{state | status: :running}}
  end

  @impl true
  def handle_cast(:pause_simulation, state) do
    {:noreply, %{state | status: :paused}}
  end

  @impl true
  def handle_cast(:resume_simulation, state) do
    schedule_next_round()
    {:noreply, %{state | status: :running}}
  end

  @impl true
  def handle_cast(:stop_simulation, state) do
    cleanup_simulation(state)
    {:noreply, %{state | status: :stopped}}
  end

  @impl true
  def handle_info(:run_round, state) do
    if state.status == :running and state.current_round < state.total_rounds do
      new_round = state.current_round + 1
      run_round(new_round, state)
      schedule_next_round()
      {:noreply, %{state | current_round: new_round}}
    else
      if state.current_round >= state.total_rounds do
        Logger.info("Simulation #{state.simulation_id} completed")
        {:noreply, %{state | status: :completed}}
      else
        {:noreply, state}
      end
    end
  end

  defp spawn_agents(graph_id, simulation_id, config) do
    {:ok, entities} = Miroex.Graph.EntityReader.get_entities(graph_id)

    Enum.map(entities, fn entity ->
      agent_name = String.to_atom("agent_#{entity["name"]}_#{simulation_id}")
      agent_id = String.length(entity["name"])

      {:ok, pid} =
        AgentSupervisor.start_agent(%{
          gen_name: agent_name,
          agent_id: agent_id,
          name: entity["name"],
          persona: entity["persona"] || "#{entity["name"]} is a #{entity["type"]}",
          platform: :twitter,
          config: config[entity["name"]] || %{},
          simulation_id: simulation_id
        })

      AgentRegistry.register(simulation_id, agent_id, pid)
      pid
    end)
  end

  defp run_round(round, state) do
    Logger.info("Running round #{round}/#{state.total_rounds}")

    Enum.each(state.agent_pids, fn agent_pid ->
      if :rand.uniform() < 0.7 do
        spawn(fn ->
          case Agent.decide_action(agent_pid) do
            :thinking ->
              :ok

            {:ok, action, _} ->
              execute_action(action, agent_pid, state)
              log_activity_to_memory(action, agent_pid, state, round)

            {:error, _} ->
              :ok
          end
        end)
      end
    end)

    if state.memory_updater_pid do
      AgentMemoryUpdater.flush(state.memory_updater_pid)
    end

    if rem(round, 10) == 0 do
      StateManager.save_full_snapshot(
        state.simulation_id,
        self(),
        state.twitter_env_pid,
        state.reddit_env_pid
      )
    end
  end

  defp execute_action(
         {:ok, %Miroex.Simulation.ActionTypes.CreatePost{content: content}},
         agent_pid,
         state
       ) do
    env_pid = state.twitter_env_pid || state.reddit_env_pid
    agent_state = Agent.get_state(agent_pid)
    Environment.create_post(env_pid, agent_state.agent_id, agent_state.name, content)
  end

  defp execute_action(
         {:ok, %Miroex.Simulation.ActionTypes.LikePost{post_id: post_id}},
         agent_pid,
         state
       ) do
    if env_pid = state.twitter_env_pid || state.reddit_env_pid do
      agent_state = Agent.get_state(agent_pid)
      Environment.like_post(env_pid, agent_state.agent_id, post_id)
    end
  end

  defp execute_action(
         {:ok, %Miroex.Simulation.ActionTypes.CommentPost{post_id: post_id, content: content}},
         agent_pid,
         state
       ) do
    if env_pid = state.twitter_env_pid || state.reddit_env_pid do
      agent_state = Agent.get_state(agent_pid)
      Environment.comment_post(env_pid, agent_state.agent_id, post_id, content)
    end
  end

  defp execute_action(
         {:ok, %Miroex.Simulation.ActionTypes.FollowUser{user_id: target_id}},
         agent_pid,
         state
       ) do
    if env_pid = state.twitter_env_pid || state.reddit_env_pid do
      agent_state = Agent.get_state(agent_pid)
      Environment.follow_user(env_pid, agent_state.agent_id, target_id)
    end
  end

  defp execute_action(
         {:ok, %Miroex.Simulation.ActionTypes.RetweetPost{post_id: post_id, content: content}},
         agent_pid,
         state
       ) do
    if env_pid = state.twitter_env_pid || state.reddit_env_pid do
      agent_state = Agent.get_state(agent_pid)
      Environment.retweet(env_pid, agent_state.agent_id, post_id, content)
    end
  end

  defp execute_action(
         {:ok, %Miroex.Simulation.ActionTypes.ReplyPost{post_id: post_id, content: content}},
         agent_pid,
         state
       ) do
    if env_pid = state.twitter_env_pid || state.reddit_env_pid do
      agent_state = Agent.get_state(agent_pid)
      Environment.comment_post(env_pid, agent_state.agent_id, post_id, content)
    end
  end

  defp execute_action(_, _, _), do: :ok

  defp log_activity_to_memory({:ok, action, _}, agent_pid, state, round) do
    agent_state = Agent.get_state(agent_pid)

    activity = %{
      graph_id: state.simulation_id,
      agent_id: agent_state.agent_id,
      agent_name: agent_state.name,
      action_type: action_type_name(action),
      content: action_content(action),
      round: round,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      metadata: %{}
    }

    if state.memory_updater_pid do
      AgentMemoryUpdater.add_activity(activity, state.memory_updater_pid)
    end
  end

  defp log_activity_to_memory(_, _, _, _), do: :ok

  defp action_type_name(%Miroex.Simulation.ActionTypes.CreatePost{}), do: "create_post"
  defp action_type_name(%Miroex.Simulation.ActionTypes.LikePost{}), do: "like_post"
  defp action_type_name(%Miroex.Simulation.ActionTypes.CommentPost{}), do: "comment_post"
  defp action_type_name(%Miroex.Simulation.ActionTypes.FollowUser{}), do: "follow_user"
  defp action_type_name(%Miroex.Simulation.ActionTypes.RetweetPost{}), do: "retweet_post"
  defp action_type_name(%Miroex.Simulation.ActionTypes.ReplyPost{}), do: "reply_post"
  defp action_type_name(_), do: "unknown"

  defp action_content(%Miroex.Simulation.ActionTypes.CreatePost{content: c}), do: c
  defp action_content(%Miroex.Simulation.ActionTypes.CommentPost{content: c}), do: c
  defp action_content(%Miroex.Simulation.ActionTypes.ReplyPost{content: c}), do: c
  defp action_content(%Miroex.Simulation.ActionTypes.RetweetPost{content: c}), do: c
  defp action_content(_), do: ""

  defp schedule_next_round, do: Process.send_after(self(), :run_round, 5000)

  defp cleanup_simulation(state) do
    Enum.each(state.agent_pids, &AgentSupervisor.stop_agent/1)
    AgentRegistry.clear_simulation(state.simulation_id)

    if state.memory_updater_pid do
      AgentMemoryUpdater.stop(state.memory_updater_pid)
    end

    StateManager.delete_simulation_state(state.simulation_id, self())
  end
end
