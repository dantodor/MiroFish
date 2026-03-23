defmodule Miroex.Simulation.Agent do
  @moduledoc """
  Individual agent GenServer that holds persona and decides actions via LLM.
  """
  use GenServer
  alias Miroex.Simulation.{LLMGateway, ActionTypes}

  @derive {Inspect, only: [:agent_id, :name, :persona, :platform, :state]}

  defstruct [:agent_id, :name, :persona, :platform, :memory, :state, :config, :simulation_id]

  @type t :: %__MODULE__{
          agent_id: integer(),
          name: String.t(),
          persona: String.t(),
          platform: :twitter | :reddit,
          memory: [map()],
          state: :idle | :thinking | :acting,
          config: map(),
          simulation_id: String.t()
        }

  def start_link(opts) do
    gen_name = Keyword.get(opts, :gen_name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: gen_name)
  end

  @impl true
  def init(opts) do
    agent = %__MODULE__{
      agent_id: Keyword.fetch!(opts, :agent_id),
      name: Keyword.fetch!(opts, :name),
      persona: Keyword.fetch!(opts, :persona),
      platform: Keyword.fetch!(opts, :platform),
      memory: [],
      state: :idle,
      config: Keyword.get(opts, :config, %{}),
      simulation_id: Keyword.fetch!(opts, :simulation_id)
    }

    {:ok, agent}
  end

  def decide_action(agent_pid) do
    GenServer.call(agent_pid, :decide_action)
  end

  def receive_memory(agent_pid, memory) do
    GenServer.cast(agent_pid, {:receive_memory, memory})
  end

  def update_config(agent_pid, config) do
    GenServer.cast(agent_pid, {:update_config, config})
  end

  def get_state(agent_pid) do
    GenServer.call(agent_pid, :get_state)
  end

  def interview(agent_pid, question) do
    GenServer.call(agent_pid, {:interview, question}, 60_000)
  end

  @impl true
  def handle_call(:decide_action, _from, agent) do
    agent = %{agent | state: :thinking}

    spawn(fn ->
      action = think_and_act(agent)
      GenServer.cast(self(), {:action_result, action})
    end)

    {:reply, :thinking, agent}
  end

  @impl true
  def handle_call(:get_state, _from, agent) do
    {:reply, agent, agent}
  end

  @impl true
  def handle_call({:interview, question}, _from, agent) do
    response = build_interview_response(agent, question)
    {:reply, {:ok, response}, agent}
  end

  @impl true
  def handle_cast({:receive_memory, memory}, agent) do
    new_memory = (agent.memory ++ memory) |> Enum.take(-100)
    {:noreply, %{agent | memory: new_memory}}
  end

  @impl true
  def handle_cast({:update_config, config}, agent) do
    {:noreply, %{agent | config: config}}
  end

  @impl true
  def handle_cast({:action_result, _action}, agent) do
    {:noreply, %{agent | state: :idle}}
  end

  defp think_and_act(agent) do
    recent_activity =
      agent.memory
      |> Enum.take(-10)
      |> Enum.map_join("\n", &format_memory/1)

    prompt = build_action_prompt(agent, recent_activity)

    case LLMGateway.request(prompt) do
      {:ok, %{content: response}} ->
        parse_llm_response(response, agent)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_action_prompt(agent, recent_activity) do
    actions =
      if agent.platform == :twitter do
        ["CREATE_POST", "LIKE_POST", "COMMENT_POST", "FOLLOW_USER", "RETWEET_POST"]
      else
        ["CREATE_POST", "LIKE_POST", "COMMENT_POST", "FOLLOW_USER"]
      end

    %{
      role: "user",
      content: """
      You are #{agent.name}. #{agent.persona}

      Recent activity in the simulation:
      #{recent_activity}

      Your configuration:
      - Activity level: #{agent.config[:activity_level] || 0.5}
      - Posts per hour: #{agent.config[:posts_per_hour] || 0.5}
      - Stance: #{agent.config[:stance] || "neutral"}

      Based on your persona and recent activity, decide what to do next.
      Available actions: #{Enum.join(actions, ", ")}

      Return your action as JSON:
      {"action": "ACTION_NAME", "content": "your post/comment content", "target_id": "post_id if applicable"}

      Only respond with valid JSON.
      """
    }
  end

  defp parse_llm_response(response, agent) do
    case Jason.decode(response) do
      {:ok, %{"action" => action, "content" => content} = parsed} ->
        action_atom = String.to_existing_atom(action)
        target_id = parsed["target_id"]

        action_struct =
          case action_atom do
            :create_post -> %ActionTypes.CreatePost{content: content}
            :like_post -> %ActionTypes.LikePost{post_id: target_id}
            :comment_post -> %ActionTypes.CommentPost{post_id: target_id, content: content}
            :follow_user -> %ActionTypes.FollowUser{user_id: target_id}
            :retweet_post -> %ActionTypes.RetweetPost{post_id: target_id, content: content}
            :reply_post -> %ActionTypes.ReplyPost{post_id: target_id, content: content}
            _ -> nil
          end

        if action_struct do
          {:ok, action_struct, agent}
        else
          {:error, :invalid_action}
        end

      _ ->
        {:error, :parse_failed}
    end
  rescue
    _ ->
      {:error, :parse_failed}
  end

  defp format_memory(memory) do
    "#{memory["agent_name"]}: #{memory["action"]} - #{memory["content"] || memory["post_id"]}"
  end

  defp build_interview_response(agent, question) do
    memory_context = format_memory_context(agent.memory)

    prompt = %{
      role: "user",
      content: """
      You are #{agent.name}. #{agent.persona}

      Recent memory:
      #{memory_context}

      Someone is asking you: "#{question}"

      Based on your persona and memory, answer this question in character.
      Be specific and reference your memory where relevant.
      """
    }

    case LLMGateway.request(prompt) do
      {:ok, %{content: response}} -> response
      {:error, reason} -> "I'm having trouble thinking right now: #{inspect(reason)}"
    end
  end

  defp format_memory_context(memory) do
    if Enum.empty?(memory) do
      "No recent activity."
    else
      memory
      |> Enum.take(-20)
      |> Enum.map_join("\n\n", fn m ->
        "#{m["agent_name"] || m["name"] || "Agent"}: #{m["action"] || "did something"} - #{m["content"] || ""}"
      end)
    end
  end
end
