defmodule Miroex.Simulation.AgentSelector do
  @moduledoc """
  LLM-based agent selection for interviews.

  Selects the most relevant agents for an interview topic using
  LLM reasoning to analyze agent personas and topic relevance.
  """

  alias Miroex.Graph.EntityReader
  alias Miroex.AI.Openrouter

  @doc """
  Selects most relevant agents for an interview topic using LLM.

  ## Parameters
    - simulation_id: The simulation ID
    - interview_topic: The topic to interview about
    - max_agents: Maximum number of agents to select (default: 5)

  ## Returns
    %{selected_agents: [%{agent_id, name, type, bio}], reasoning: "..."}
  """
  @spec select_agents(String.t(), String.t(), non_neg_integer()) :: %{
          selected_agents: [
            %{agent_id: integer(), name: String.t(), type: String.t(), bio: String.t()}
          ],
          reasoning: String.t()
        }
  def select_agents(simulation_id, interview_topic, max_agents \\ 5) do
    with {:ok, entities} <- EntityReader.get_entities(simulation_id) do
      do_select_agents(entities, interview_topic, max_agents)
    else
      _error ->
        %{selected_agents: [], reasoning: "No entities found in graph"}
    end
  end

  @doc """
  Selects agents with simulation requirement context.

  ## Parameters
    - simulation_id: The simulation ID
    - interview_topic: The topic to interview about
    - max_agents: Maximum number of agents to select
    - simulation_requirement: The overall simulation requirement for context

  ## Returns
    %{selected_agents: [%{agent_id, name, type, bio}], reasoning: "..."}
  """
  @spec select_agents(String.t(), String.t(), non_neg_integer(), String.t()) :: %{
          selected_agents: [
            %{agent_id: integer(), name: String.t(), type: String.t(), bio: String.t()}
          ],
          reasoning: String.t()
        }
  def select_agents(simulation_id, interview_topic, max_agents, simulation_requirement) do
    with {:ok, entities} <- EntityReader.get_entities(simulation_id) do
      do_select_agents_with_context(entities, interview_topic, max_agents, simulation_requirement)
    else
      _error ->
        %{selected_agents: [], reasoning: "No entities found in graph"}
    end
  end

  defp do_select_agents(entities, interview_topic, max_agents) do
    system_prompt = """
    You are an expert at selecting relevant agents for interviews.
    Your task is to analyze a list of agents and select the #{max_agents} most relevant ones
    for a given interview topic.

    Consider:
    - Agent type/role (e.g., student, professor, media, official)
    - Agent name and potential relevance to the topic
    - Diversity of perspectives (select different types if relevant)

    Return ONLY a JSON object in this format:
    {
      "selected_agents": [0, 1, 2],  // array of indices (0-based)
      "reasoning": "Explanation of why these agents were selected..."
    }
    """

    user_prompt = build_agent_selection_prompt(entities, interview_topic)

    case Openrouter.chat([
           %{role: "system", content: system_prompt},
           %{role: "user", content: user_prompt}
         ]) do
      {:ok, %{"content" => content}} ->
        case Jason.decode(content) do
          {:ok, %{"selected_agents" => indices, "reasoning" => reasoning}} ->
            selected =
              Enum.map(indices, fn idx ->
                entity = Enum.at(entities, idx)

                %{
                  agent_id: idx + 1,
                  name: entity["name"] || "Unknown",
                  type: entity["type"] || "Unknown",
                  bio: entity["properties"] || ""
                }
              end)

            %{selected_agents: selected, reasoning: reasoning}

          _decode_error ->
            fallback_selection(entities, interview_topic, max_agents)
        end

      _error ->
        # Fallback to simple selection if LLM fails
        fallback_selection(entities, interview_topic, max_agents)
    end
  end

  defp do_select_agents_with_context(
         entities,
         interview_topic,
         max_agents,
         simulation_requirement
       ) do
    system_prompt = """
    You are an expert at selecting relevant agents for interviews.
    Your task is to analyze a list of agents and select the #{max_agents} most relevant ones
    for a given interview topic within the context of a simulation.

    Simulation Context:
    #{simulation_requirement}

    Consider:
    - Agent type/role (e.g., student, professor, media, official)
    - Agent name and potential relevance to the topic
    - Diversity of perspectives (select different types if relevant)
    - Which agents would realistically have opinions on this topic given the simulation context

    Return ONLY a JSON object in this format:
    {
      "selected_agents": [0, 1, 2],  // array of indices (0-based)
      "reasoning": "Explanation of why these agents were selected..."
    }
    """

    user_prompt = build_agent_selection_prompt(entities, interview_topic)

    case Openrouter.chat([
           %{role: "system", content: system_prompt},
           %{role: "user", content: user_prompt}
         ]) do
      {:ok, %{"content" => content}} ->
        case Jason.decode(content) do
          {:ok, %{"selected_agents" => indices, "reasoning" => reasoning}} ->
            selected =
              Enum.map(indices, fn idx ->
                entity = Enum.at(entities, idx)

                %{
                  agent_id: idx + 1,
                  name: entity["name"] || "Unknown",
                  type: entity["type"] || "Unknown",
                  bio: entity["properties"] || ""
                }
              end)

            %{selected_agents: selected, reasoning: reasoning}

          _decode_error ->
            fallback_selection(entities, interview_topic, max_agents)
        end

      _error ->
        fallback_selection(entities, interview_topic, max_agents)
    end
  end

  defp build_agent_selection_prompt(entities, interview_topic) do
    agent_list =
      entities
      |> Enum.with_index()
      |> Enum.map(fn {entity, idx} ->
        name = entity["name"] || "Unknown"
        type = entity["type"] || "Unknown"
        props = entity["properties"] || ""

        "#{idx}. #{name} (Type: #{type})\n   Bio: #{props}"
      end)
      |> Enum.join("\n\n")

    """
    Interview Topic: #{interview_topic}

    Available Agents:
    #{agent_list}

    Select the #{length(entities)} most relevant agents for this interview.
    Return their indices (0-based) as a JSON array.
    """
  end

  defp fallback_selection(entities, interview_topic, max_agents) do
    topic_lower = String.downcase(interview_topic)

    scored =
      Enum.with_index(entities)
      |> Enum.map(fn {entity, idx} ->
        name = String.downcase(entity["name"] || "")
        type = String.downcase(entity["type"] || "")

        score =
          cond do
            String.contains?(name, topic_lower) -> 80
            String.contains?(type, topic_lower) -> 60
            String.contains?(topic_lower, type) -> 40
            true -> 10
          end

        {idx, entity, score}
      end)
      |> Enum.sort_by(fn {_, _, score} -> score end, :desc)
      |> Enum.take(max_agents)

    selected =
      Enum.map(scored, fn {idx, entity, _} ->
        %{
          agent_id: idx + 1,
          name: entity["name"] || "Unknown",
          type: entity["type"] || "Unknown",
          bio: entity["properties"] || ""
        }
      end)

    types = Enum.map(selected, & &1.type) |> Enum.uniq() |> Enum.join(", ")

    reasoning =
      "Selected #{length(selected)} agents based on name/type relevance to topic. Agent types: #{types}."

    %{selected_agents: selected, reasoning: reasoning}
  end
end
