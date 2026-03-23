defmodule Miroex.Reports.ReportLogger do
  @moduledoc """
  JSONL-based logging for report generation for debugging and replay.
  """

  @doc """
  Log a report event (tool call, LLM response, etc.)
  """
  @spec log_event(String.t(), map()) :: :ok | {:error, term()}
  def log_event(report_id, event) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    log_line = Jason.encode!(%{timestamp: timestamp, event: event})

    path = log_path(report_id)

    with :ok <- mkdir_p(Path.dirname(path)) do
      File.write(path, log_line <> "\n", [:append])
    end
  end

  @doc """
  Log a tool call made by the report agent.
  """
  @spec log_tool_call(String.t(), String.t(), map()) :: :ok
  def log_tool_call(report_id, tool_name, args) do
    log_event(report_id, %{
      type: "tool_call",
      tool: tool_name,
      args: args
    })
  end

  @doc """
  Log a tool result received by the report agent.
  """
  @spec log_tool_result(String.t(), String.t(), term()) :: :ok
  def log_tool_result(report_id, tool_name, result) do
    log_event(report_id, %{
      type: "tool_result",
      tool: tool_name,
      result: inspect(result, limit: 1000)
    })
  end

  @doc """
  Log an LLM response.
  """
  @spec log_llm_response(String.t(), String.t()) :: :ok
  def log_llm_response(report_id, content) do
    log_event(report_id, %{
      type: "llm_response",
      content: String.slice(content, 0, 5000)
    })
  end

  @doc """
  Log report planning start.
  """
  @spec log_planning_start(String.t(), String.t(), String.t()) :: :ok
  def log_planning_start(report_id, simulation_id, simulation_requirement) do
    log_event(report_id, %{
      type: "planning_start",
      simulation_id: simulation_id,
      simulation_requirement: simulation_requirement
    })
  end

  @doc """
  Log outline planning complete.
  """
  @spec log_planning_complete(String.t(), map()) :: :ok
  def log_planning_complete(report_id, outline) do
    log_event(report_id, %{
      type: "planning_complete",
      outline: outline
    })
  end

  @doc """
  Log section generation start.
  """
  @spec log_section_start(String.t(), String.t(), non_neg_integer()) :: :ok
  def log_section_start(report_id, section_title, section_index) do
    log_event(report_id, %{
      type: "section_start",
      section_title: section_title,
      section_index: section_index
    })
  end

  @doc """
  Log a ReACT thought (LLM reasoning before tool call).
  """
  @spec log_react_thought(String.t(), non_neg_integer(), String.t()) :: :ok
  def log_react_thought(report_id, iteration, thought) do
    log_event(report_id, %{
      type: "react_thought",
      iteration: iteration,
      thought: String.slice(thought, 0, 2000)
    })
  end

  @doc """
  Log section content generation (partial content during generation).
  """
  @spec log_section_content(String.t(), String.t(), non_neg_integer(), String.t()) :: :ok
  def log_section_content(report_id, section_title, section_index, content) do
    log_event(report_id, %{
      type: "section_content",
      section_title: section_title,
      section_index: section_index,
      content: String.slice(content, 0, 10000),
      content_length: String.length(content)
    })
  end

  @doc """
  Log section generation complete (full content).
  """
  @spec log_section_complete(String.t(), String.t(), non_neg_integer(), String.t()) :: :ok
  def log_section_complete(report_id, section_title, section_index, content) do
    log_event(report_id, %{
      type: "section_complete",
      section_title: section_title,
      section_index: section_index,
      content: content,
      content_length: String.length(content)
    })
  end

  @doc """
  Log report generation complete.
  """
  @spec log_report_complete(String.t(), non_neg_integer(), integer()) :: :ok
  def log_report_complete(report_id, total_sections, duration_ms) do
    log_event(report_id, %{
      type: "report_complete",
      total_sections: total_sections,
      duration_ms: duration_ms
    })
  end

  @doc """
  Log report generation error.
  """
  @spec log_error(String.t(), String.t(), String.t() | nil) :: :ok
  def log_error(report_id, error_message, section_title \\ nil) do
    log_event(report_id, %{
      type: "error",
      error: error_message,
      section_title: section_title
    })
  end

  @doc """
  Get all log entries for a report.
  """
  @spec get_logs(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_logs(report_id) do
    path = log_path(report_id)

    case File.read(path) do
      {:ok, content} ->
        lines = String.split(content, "\n", trim: true)
        events = Enum.map(lines, &parse_log_line/1) |> Enum.reject(&is_nil/1)
        {:ok, events}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get logs filtered by event type.
  """
  @spec get_logs_by_type(String.t(), String.t()) :: {:ok, [map()]}
  def get_logs_by_type(report_id, type) do
    with {:ok, all} <- get_logs(report_id) do
      filtered = Enum.filter(all, &(&1["event"] && &1["event"]["type"] == type))
      {:ok, filtered}
    end
  end

  @doc """
  Get tool calls only for a report.
  """
  @spec get_tool_calls(String.t()) :: {:ok, [map()]}
  def get_tool_calls(report_id) do
    get_logs_by_type(report_id, "tool_call")
  end

  @doc """
  Get LLM responses only for a report.
  """
  @spec get_llm_responses(String.t()) :: {:ok, [map()]}
  def get_llm_responses(report_id) do
    get_logs_by_type(report_id, "llm_response")
  end

  defp log_path(report_id) do
    log_dir = Application.get_env(:miroex, :reports_log_dir, "priv/reports_logs")
    Path.join([log_dir, "#{report_id}.jsonl"])
  end

  defp mkdir_p(path) do
    case File.mkdir_p(path) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      error -> error
    end
  end

  defp parse_log_line(line) do
    case Jason.decode(line) do
      {:ok, map} -> map
      _ -> nil
    end
  end
end
