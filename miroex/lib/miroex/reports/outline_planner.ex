defmodule Miroex.Reports.OutlinePlanner do
  @moduledoc """
  Generate report outline using LLM based on simulation context.

  This implements the planning phase similar to the Python implementation:
  1. Gather simulation context (graph stats, sample facts)
  2. Send to LLM with planning prompt
  3. Parse JSON response into structured outline
  """
  alias Miroex.AI.{Openrouter, JSONHelper}
  alias Miroex.AI.Tools.GraphSearch

  @min_sections 2
  @max_sections 5

  @doc """
  Generate a report outline based on simulation context.

  ## Parameters
    - simulation_id: The simulation ID
    - graph_id: The graph ID for context
    - simulation_requirement: The user's simulation requirement/goal

  ## Returns
    {:ok, %Outline{}} or {:error, reason}
  """
  @spec plan(String.t(), String.t(), String.t()) :: {:ok, Outline.t()} | {:error, term()}
  def plan(simulation_id, graph_id, simulation_requirement) do
    with {:ok, context} <- gather_context(graph_id, simulation_requirement),
         {:ok, outline_data} <- generate_outline_with_llm(context, simulation_requirement) do
      outline = build_outline_struct(outline_data)
      {:ok, outline}
    else
      {:error, reason} ->
        {:ok, default_outline(simulation_requirement)}
    end
  end

  defstruct [:title, :summary, sections: []]

  @type t :: %__MODULE__{
          title: String.t(),
          summary: String.t(),
          sections: [Section.t()]
        }

  defmodule Section do
    defstruct [:title, :description]

    @type t :: %__MODULE__{
            title: String.t(),
            description: String.t()
          }
  end

  defp gather_context(graph_id, simulation_requirement) do
    context = %{
      graph_stats: %{},
      sample_facts: [],
      entity_types: [],
      total_entities: 0
    }

    context =
      case GraphSearch.panorama_search(graph_id, top_k: 20) do
        {:ok, result} ->
          stats = get_in(result, [:overview]) || %{}

          %{
            context
            | graph_stats: %{
                total_nodes: stats[:total_entities] || 0,
                total_edges: stats[:total_relations] || 0,
                entity_types: stats[:entity_types] || []
              },
              entity_types: stats[:entity_types] || [],
              total_entities: stats[:total_entities] || 0
          }

        _ ->
          context
      end

    context =
      case GraphSearch.insight_forge(graph_id, simulation_requirement, top_k: 10) do
        {:ok, result} ->
          facts =
            result[:results] ||
              []
              |> Enum.map(fn entity ->
                related = entity[:related_relations] || []
                facts = related |> Enum.map(&"#{&1.direction}: #{&1.to}(#{&1.type})")
                entity[:name] <> " - " <> Enum.join(facts, ", ")
              end)

          %{context | sample_facts: Enum.take(facts, 10)}

        _ ->
          context
      end

    {:ok, context}
  end

  defp generate_outline_with_llm(context, simulation_requirement) do
    prompt = build_planning_prompt(context, simulation_requirement)

    messages = [
      %{role: "system", content: planning_system_prompt()},
      %{role: "user", content: prompt}
    ]

    case Openrouter.chat(messages, "openai/gpt-4o-mini") do
      {:ok, %{content: content}} ->
        case JSONHelper.parse_with_fallback(content, required_fields: ["title", "sections"]) do
          {:ok, data} when is_map(data) and map_size(data) > 0 ->
            sections = Map.get(data, "sections", [])

            if is_list(sections) and length(sections) > 0 do
              {:ok, data}
            else
              {:ok, data}
            end

          _ ->
            {:error, :parse_failed}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp planning_system_prompt do
    """
    You are an expert at writing "future prediction reports" with a "god's eye view" of simulation worlds.

    Your task is to write a "future prediction report" that answers:
    1. What happens in the future under our set conditions?
    2. How do various agents (people) react and act?
    3. What future trends and risks does this simulation reveal?

    Report characteristics:
    - This is a future prediction report based on simulation, revealing "what will happen if..."
    - Focus on prediction results: event trends, group reactions, emerging phenomena, potential risks
    - Agent words and actions in the simulation world are predictions of future group behavior

    Section requirements:
    - Minimum 2 sections, maximum 5 sections
    - No sub-sections needed, each section should be complete content
    - Content should be concise and focused on core prediction findings
    - Section structure is designed by you based on prediction results

    Return JSON format:
    {
        "title": "Report Title",
        "summary": "Report summary (one sentence summarizing core prediction findings)",
        "sections": [
            {
                "title": "Section Title",
                "description": "Section content description"
            }
        ]
    }

    Note: sections array must have minimum 2, maximum 5 elements!
    """
  end

  defp build_planning_prompt(context, simulation_requirement) do
    graph_stats = context.graph_stats

    """
    【Prediction Scenario Settings】
    The variables we injected into the simulation world (simulation requirement): #{simulation_requirement}

    【Simulation World Scale】
    - Number of entities participating in simulation: #{Map.get(graph_stats, :total_nodes, 0)}
    - Number of relationships between entities: #{Map.get(graph_stats, :total_edges, 0)}
    - Entity type distribution: #{inspect(context.entity_types)}
    - Number of active agents: #{context.total_entities}

    【Sample Future Facts Predicted by Simulation】
    #{format_sample_facts(context.sample_facts)}

    Please examine this future preview from a "god's eye view":
    1. What does the future look like under our set conditions?
    2. How do various groups (agents) react and act?
    3. What future trends does this simulation reveal?

    Based on prediction results, design the most suitable report section structure.

    【Reminder】Report must have minimum 2 sections, maximum 5 sections, content should be concise and focused on core prediction findings.
    """
  end

  defp format_sample_facts([]), do: "No facts available"

  defp format_sample_facts(facts) do
    facts
    |> Enum.with_index(1)
    |> Enum.map(fn {fact, i} -> "#{i}. #{fact}" end)
    |> Enum.join("\n")
  end

  defp build_outline_struct(data) when is_map(data) do
    title = data["title"] || "Future Prediction Report"
    summary = data["summary"] || "Analysis of simulation predictions"

    sections =
      (data["sections"] || [])
      |> Enum.take(@max_sections)
      |> Enum.with_index()
      |> Enum.map(fn {s, i} ->
        %Section{
          title: s["title"] || "Section #{i + 1}",
          description: s["description"] || ""
        }
      end)

    %__MODULE__{
      title: title,
      summary: summary,
      sections: sections
    }
  end

  defp default_outline(simulation_requirement) do
    %__MODULE__{
      title: "Future Prediction Report",
      summary: "Analysis based on simulation: #{simulation_requirement}",
      sections: [
        %Section{
          title: "Prediction Scenario and Core Findings",
          description: "Overview of predicted events and key outcomes"
        },
        %Section{
          title: "Group Behavior Prediction Analysis",
          description: "Analysis of how different groups react and behave"
        },
        %Section{
          title: "Trend Outlook and Risk Warning",
          description: "Future trends and potential risks identified"
        }
      ]
    }
  end
end
