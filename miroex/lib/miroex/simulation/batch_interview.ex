defmodule Miroex.Simulation.BatchInterview do
  @moduledoc """
  Batch interview functionality for interviewing multiple agents.

  Supports dual-platform interviews (Twitter, Reddit, or both).
  """

  alias Miroex.Simulation.{Agent, AgentRegistry}

  @type interview_request :: %{
          agent_id: integer(),
          prompt: String.t()
        }

  @type interview_result :: %{
          agent_id: integer(),
          agent_name: String.t(),
          platform: :twitter | :reddit,
          response: String.t()
        }

  @doc """
  Conducts batch interviews with multiple agents.

  ## Parameters
    - simulation_id: The simulation ID
    - interviews: List of %{agent_id, prompt} maps
    - platform: :twitter | :reddit | :both | nil (nil means both)
    - timeout: Timeout in milliseconds (default: 180_000)

  ## Returns
    {:ok, %{interviews_count: integer(), results: [interview_result]}} |
    {:error, String.t()}
  """
  @spec batch_interview(String.t(), [interview_request()], atom() | nil, non_neg_integer()) ::
          {:ok, map()} | {:error, String.t()}
  def batch_interview(simulation_id, interviews, platform \\ nil, _timeout \\ 180_000) do
    platforms = determine_platforms(platform)

    results =
      interviews
      |> Enum.flat_map(fn %{agent_id: agent_id, prompt: prompt} ->
        interview_agent_on_platforms(simulation_id, agent_id, prompt, platforms)
      end)
      |> Enum.filter(fn result -> result.response != nil end)

    {:ok,
     %{
       interviews_count: length(results),
       results: results
     }}
  rescue
    e ->
      {:error, "Batch interview failed: #{inspect(e)}"}
  end

  @doc """
  Generates interview questions based on the topic.

  Uses LLM to generate relevant questions for the interview topic.

  ## Parameters
    - interview_topic: The topic to generate questions about
    - simulation_requirement: Optional simulation context
    - num_questions: Number of questions to generate (default: 3)

  ## Returns
    [String.t()]
  """
  @spec generate_interview_questions(String.t(), String.t() | nil, non_neg_integer()) :: [
          String.t()
        ]
  def generate_interview_questions(
        interview_topic,
        simulation_requirement \\ nil,
        num_questions \\ 3
      ) do
    system_prompt = """
    You are an expert interviewer. Generate #{num_questions} insightful questions
    for interviewing simulation agents about a specific topic.

    The questions should:
    - Be open-ended to encourage detailed responses
    - Be relevant to the agent's perspective and the topic
    - Help gather diverse viewpoints
    - Be suitable for social media simulation contexts

    Return ONLY a JSON array of question strings.
    """

    user_prompt =
      if simulation_requirement do
        """
        Simulation Context: #{simulation_requirement}

        Interview Topic: #{interview_topic}

        Generate #{num_questions} questions for interviewing agents about this topic
        within the simulation context.
        """
      else
        """
        Interview Topic: #{interview_topic}

        Generate #{num_questions} questions for interviewing agents about this topic.
        """
      end

    case Miroex.AI.Openrouter.chat([
           %{role: "system", content: system_prompt},
           %{role: "user", content: user_prompt}
         ]) do
      {:ok, %{"content" => content}} ->
        # Parse JSON content
        case Jason.decode(content) do
          {:ok, questions} when is_list(questions) ->
            questions |> Enum.take(num_questions)

          {:ok, %{} = map} ->
            Map.get(map, "questions", ["What are your thoughts on this topic?"])

          _ ->
            fallback_questions(interview_topic)
        end

      _error ->
        fallback_questions(interview_topic)
    end
  end

  defp fallback_questions(interview_topic) do
    [
      "What are your thoughts on #{interview_topic}?",
      "How has #{interview_topic} affected you personally?",
      "What do you think should be done about #{interview_topic}?"
    ]
  end

  @doc """
  Formats interview questions into a combined prompt.

  Adds context instructions for the agent on how to respond.

  ## Parameters
    - questions: List of question strings

  ## Returns
    String.t()
  """
  @spec format_interview_prompt([String.t()]) :: String.t()
  def format_interview_prompt(questions) do
    numbered_questions =
      questions
      |> Enum.with_index(1)
      |> Enum.map(fn {q, idx} -> "#{idx}. #{q}" end)
      |> Enum.join("\n")

    """
    You are being interviewed about your perspective on a topic.

    Instructions:
    - Answer directly and naturally in first person
    - Do not call any tools or functions
    - Do not return JSON or structured data
    - Respond as if you're posting on social media
    - Keep responses authentic to your character

    Questions:
    #{numbered_questions}

    Please answer each question. Number your responses clearly.
    """
  end

  # Private functions

  defp determine_platforms(nil), do: [:twitter, :reddit]
  defp determine_platforms(:both), do: [:twitter, :reddit]
  defp determine_platforms(platform) when is_atom(platform), do: [platform]

  defp determine_platforms(platform) when is_binary(platform) do
    case String.downcase(platform) do
      "twitter" -> [:twitter]
      "reddit" -> [:reddit]
      "both" -> [:twitter, :reddit]
      _ -> [:twitter, :reddit]
    end
  end

  defp interview_agent_on_platforms(simulation_id, agent_id, prompt, platforms) do
    Enum.map(platforms, fn platform ->
      case interview_single_agent(simulation_id, agent_id, prompt, platform) do
        {:ok, response, agent_name} ->
          %{
            agent_id: agent_id,
            agent_name: agent_name,
            platform: platform,
            response: response
          }

        {:error, reason} ->
          %{
            agent_id: agent_id,
            agent_name: get_agent_name(simulation_id, agent_id),
            platform: platform,
            response: "[Error: #{reason}]"
          }
      end
    end)
  end

  defp interview_single_agent(simulation_id, agent_id, prompt, platform) do
    with {:ok, agent_pid} <- AgentRegistry.lookup(simulation_id, agent_id),
         platform_prompt = add_platform_context(prompt, platform),
         {:ok, response} <- Agent.interview(agent_pid, platform_prompt),
         agent_state <- Agent.get_state(agent_pid) do
      {:ok, response, agent_state.name}
    else
      :error ->
        {:error, :agent_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_platform_context(prompt, platform) do
    context =
      case platform do
        :twitter ->
          "[You are currently on Twitter - be concise and punchy]\n\n"

        :reddit ->
          "[You are currently on Reddit - be detailed and thoughtful]\n\n"

        _ ->
          ""
      end

    context <> prompt
  end

  defp get_agent_name(simulation_id, agent_id) do
    case AgentRegistry.lookup(simulation_id, agent_id) do
      {:ok, agent_pid} ->
        state = Agent.get_state(agent_pid)
        state.name

      :error ->
        "Agent #{agent_id}"
    end
  end
end
