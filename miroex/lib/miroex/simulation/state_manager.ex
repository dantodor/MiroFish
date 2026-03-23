defmodule Miroex.Simulation.StateManager do
  @moduledoc """
  Persists simulation state to disk for fault tolerance and replay.
  Saves: orchestrator state, agent states, and environment states.
  """

  alias Miroex.Simulation.{
    Agent,
    AgentRegistry,
    Serializers.AgentState,
    Serializers.EnvironmentState
  }

  def state_dir, do: Application.get_env(:miroex, :simulation_state_dir, "priv/simulation_states")

  @doc """
  Save orchestrator state to disk.
  """
  @spec save_orchestrator_state(map()) :: :ok | {:error, term()}
  def save_orchestrator_state(state) do
    path = orchestrator_path(state.simulation_id)
    File.mkdir_p!(Path.dirname(path))

    serialized = %{
      simulation_id: state.simulation_id,
      project_id: state.project_id,
      user_id: state.user_id,
      current_round: state.current_round,
      total_rounds: state.total_rounds,
      status: Atom.to_string(state.status),
      config: state.config,
      twitter_env_pid: state.twitter_env_pid,
      reddit_env_pid: state.reddit_env_pid,
      agent_pids: state.agent_pids,
      memory_updater_pid: state.memory_updater_pid,
      saved_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    File.write!(path, Jason.encode!(serialized, pretty: true))
  end

  @doc """
  Save all agent states via AgentRegistry.
  """
  @spec save_all_agent_states(String.t()) :: :ok | {:error, term()}
  def save_all_agent_states(simulation_id) do
    agents = AgentRegistry.agents_by_simulation(simulation_id)

    serialized_agents =
      Enum.map(agents, fn {_agent_id, agent_pid} ->
        agent_state = Agent.get_state(agent_pid)
        AgentState.serialize(Map.from_struct(agent_state))
      end)

    path = agents_path(simulation_id)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(serialized_agents, pretty: true))
  end

  @doc """
  Save environment states (Twitter and Reddit).
  """
  @spec save_environment_states(pid(), pid() | nil, pid() | nil) :: :ok | {:error, term()}
  def save_environment_states(orch_pid, twitter_env_pid, reddit_env_pid) do
    env_states = []

    env_states =
      if twitter_env_pid && Process.alive?(twitter_env_pid) do
        state = :sys.get_state(twitter_env_pid)
        serialized = EnvironmentState.serialize(state)
        [{"twitter", serialized} | env_states]
      else
        env_states
      end

    env_states =
      if reddit_env_pid && Process.alive?(reddit_env_pid) do
        state = :sys.get_state(reddit_env_pid)
        serialized = EnvironmentState.serialize(state)
        [{"reddit", serialized} | env_states]
      else
        env_states
      end

    if env_states != [] do
      path = env_path(orch_pid)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, Jason.encode!(env_states, pretty: true))
    else
      :ok
    end
  end

  @doc """
  Save full snapshot of all simulation state.
  """
  @spec save_full_snapshot(String.t(), pid(), pid() | nil, pid() | nil) :: :ok | {:error, term()}
  def save_full_snapshot(simulation_id, orch_pid, twitter_env_pid, reddit_env_pid) do
    orch_state = :sys.get_state(orch_pid)

    with :ok <- save_orchestrator_state(Map.from_struct(orch_state)),
         :ok <- save_all_agent_states(simulation_id),
         :ok <- save_environment_states(orch_pid, twitter_env_pid, reddit_env_pid) do
      :ok
    else
      error -> error
    end
  end

  @doc """
  Load orchestrator state from disk.
  """
  @spec load_orchestrator_state(String.t()) :: {:ok, map()} | {:error, term()}
  def load_orchestrator_state(simulation_id) do
    path = orchestrator_path(simulation_id)

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, state} ->
            atom_state = atomize_keys(state)

            atom_state =
              if atom_state[:status] && is_binary(atom_state[:status]) do
                %{atom_state | status: String.to_existing_atom(atom_state[:status])}
              else
                atom_state
              end

            {:ok, atom_state}

          error ->
            error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      Map.put(acc, key, atomize_keys(v))
    end)
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(other), do: other

  @doc """
  Load agent states from disk.
  """
  @spec load_agent_states(String.t()) :: {:ok, [map()]} | {:error, term()}
  def load_agent_states(simulation_id) do
    path = agents_path(simulation_id)

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, agents} when is_list(agents) ->
            deserialized = Enum.map(agents, &AgentState.deserialize/1)
            {:ok, deserialized}

          {:ok, _} ->
            {:ok, []}

          error ->
            error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Load environment states from disk.
  """
  @spec load_environment_states(pid()) :: {:ok, [{atom(), map()}]} | {:error, term()}
  def load_environment_states(orch_pid) do
    path = env_path(orch_pid)

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, envs} when is_list(envs) ->
            deserialized =
              Enum.map(envs, fn {platform, state} ->
                {String.to_existing_atom(platform), EnvironmentState.deserialize(state)}
              end)

            {:ok, deserialized}

          {:ok, _} ->
            {:ok, []}

          error ->
            error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if saved state exists for simulation.
  """
  @spec state_exists?(String.t()) :: boolean()
  def state_exists?(simulation_id) do
    File.exists?(orchestrator_path(simulation_id))
  end

  @doc """
  Delete all saved state for simulation.
  """
  @spec delete_simulation_state(String.t(), pid()) :: :ok
  def delete_simulation_state(simulation_id, orch_pid) do
    orchestrator_path(simulation_id) |> File.rm()
    agents_path(simulation_id) |> File.rm()
    env_path(orch_pid) |> File.rm()
    :ok
  end

  @doc """
  List all saved simulation IDs.
  """
  @spec list_saved_states() :: [String.t()]
  def list_saved_states do
    case File.ls(state_dir()) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, "_orchestrator.json"))
        |> Enum.map(&String.replace(&1, "_orchestrator.json", ""))

      _ ->
        []
    end
  end

  defp orchestrator_path(simulation_id) do
    Path.join([state_dir(), "#{simulation_id}_orchestrator.json"])
  end

  defp agents_path(simulation_id) do
    Path.join([state_dir(), "#{simulation_id}_agents.json"])
  end

  defp env_path(orch_pid) do
    pid_str = :erlang.pid_to_list(orch_pid) |> List.to_string()
    hash = :crypto.hash(:md5, pid_str) |> Base.encode16() |> String.downcase()
    Path.join([state_dir(), "env_#{hash}.json"])
  end
end
