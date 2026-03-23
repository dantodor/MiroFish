defmodule Miroex.Reports.ReportAgent do
  @moduledoc """
  Report generation agent with tool-calling capabilities.
  """
  alias Miroex.AI.{Openrouter, Tools.GraphSearch, Tools.Statistics}
  alias Miroex.Reports.ReportLogger

  @system_prompt """
  You are a simulation analysis expert. Generate comprehensive reports about social media simulations.

  You have access to tools:
  - graph_search: Search entities in the knowledge graph (basic text search)
  - graph_search_by_type: Get entities of a specific type
  - get_entity_types: List all entity types in the graph
  - insight_forge: Deep search with relationship context (use for detailed entity analysis)
  - panorama_search: Get complete overview of graph structure (use for broad analysis)
  - get_relation_chains: Get relationship paths between entities (use for tracing connections)
  - statistics: Get simulation action statistics

  Use these tools to gather data, then synthesize a detailed report.
  Always respond with JSON in this format:
  {"tool": "tool_name", "args": {"arg1": "value1"}}
  Or for final report:
  {"report": "Your full report content here"}
  """

  def generate_report(simulation_id, graph_id) do
    messages = [
      %{role: "system", content: @system_prompt},
      %{
        role: "user",
        content:
          "Generate a comprehensive report about this simulation. Include analysis of entities, agent behaviors, and key findings."
      }
    ]

    collect_report(messages, simulation_id, graph_id, [])
  end

  def chat(simulation_id, graph_id, user_message) do
    messages = [
      %{role: "system", content: @system_prompt},
      %{role: "user", content: user_message}
    ]

    collect_report(messages, simulation_id, graph_id, [])
  end

  defp collect_report(messages, simulation_id, graph_id, tool_results) do
    last_message = List.last(messages)
    ReportLogger.log_llm_response(simulation_id, last_message.content)

    case Openrouter.chat(messages) do
      {:ok, %{content: content}} ->
        content = String.trim(content)
        ReportLogger.log_llm_response(simulation_id, content)

        case Jason.decode(content) do
          {:ok, %{"tool" => tool, "args" => args}} ->
            ReportLogger.log_tool_call(simulation_id, tool, args)
            result = execute_tool(tool, args, simulation_id, graph_id)
            ReportLogger.log_tool_result(simulation_id, tool, result)

            new_messages =
              messages ++ [%{role: "user", content: "Tool result: #{inspect(result)}"}]

            collect_report(new_messages, simulation_id, graph_id, [result | tool_results])

          {:ok, %{"report" => report}} ->
            {:ok, report}

          _ ->
            {:ok, content}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_tool("graph_search", args, _simulation_id, graph_id) do
    GraphSearch.execute(graph_id, args["query"] || "")
  end

  defp execute_tool("graph_search_by_type", args, _simulation_id, graph_id) do
    GraphSearch.execute_by_type(graph_id, args["type"] || "")
  end

  defp execute_tool("get_entity_types", _args, _simulation_id, graph_id) do
    GraphSearch.get_types(graph_id)
  end

  defp execute_tool("statistics", _args, simulation_id, _graph_id) do
    Statistics.execute(simulation_id)
  end

  defp execute_tool("insight_forge", args, _simulation_id, graph_id) do
    GraphSearch.insight_forge(graph_id, args["query"] || "", top_k: 10)
  end

  defp execute_tool("panorama_search", _args, _simulation_id, graph_id) do
    GraphSearch.panorama_search(graph_id, top_k: 20)
  end

  defp execute_tool("get_relation_chains", args, _simulation_id, graph_id) do
    GraphSearch.get_relation_chains(graph_id, args["entity"] || "", depth: 3)
  end

  defp execute_tool(tool, args, _simulation_id, _graph_id) do
    {:error, "Unknown tool: #{tool} with args: #{inspect(args)}"}
  end
end
