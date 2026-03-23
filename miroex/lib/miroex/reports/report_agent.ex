defmodule Miroex.Reports.ReportAgent do
  @moduledoc """
  Report generation agent with planning and section-by-section generation.

  Implements the ReACT pattern similar to the Python implementation:
  1. Planning phase: Generate outline based on simulation context
  2. Section generation: Each section uses ReACT loop to gather data
  3. Final output: Markdown report stored in database

  The agent has access to tools:
  - graph_search: Basic entity search
  - insight_forge: Deep search with relationship context
  - panorama_search: Full graph overview
  - statistics: Simulation action statistics
  - get_relation_chains: Relationship path tracing
  - interview_agents: Interview simulation agents
  """
  alias Miroex.AI.{Openrouter, JSONHelper}
  alias Miroex.AI.Tools.GraphSearch
  alias Miroex.AI.Tools.Statistics
  alias Miroex.Reports.{OutlinePlanner, ReportProgress, ReportLogger, ReportSection}

  @max_tool_calls_per_section 5
  @min_tool_calls_per_section 3
  @max_reflection_rounds 3

  @tools_description """
  Available tools (use JSON format for tool calls):

  1. graph_search: Basic text search for entities
     {"tool": "graph_search", "args": {"query": "search term"}}

  2. insight_forge: Deep search with relationship context (best for detailed analysis)
     {"tool": "insight_forge", "args": {"query": "analysis topic", "top_k": 10}}

  3. panorama_search: Complete graph overview (best for broad understanding)
     {"tool": "panorama_search", "args": {"top_k": 20}}

  4. statistics: Get simulation action statistics
     {"tool": "statistics", "args": {}}

  5. get_relation_chains: Trace relationship paths between entities
     {"tool": "get_relation_chains", "args": {"entity": "entity name", "depth": 3}}

  6. interview_agents: Interview simulation agents about their views
     {"tool": "interview_agents", "args": {"interview_topic": "topic to discuss", "max_agents": 5}}

  For final answer (when you have gathered enough information):
  {"report": "Your detailed section content here"}
  """

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Generate a complete report with planning and section-by-section generation.

  ## Parameters
    - simulation_id: The simulation ID
    - graph_id: The graph ID for context
    - simulation_requirement: The user's simulation requirement

  ## Returns
    {:ok, report_content} or {:error, reason}
  """
  @spec generate_report(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_report(simulation_id, graph_id, simulation_requirement)
      when is_binary(simulation_id) and is_binary(graph_id) and is_binary(simulation_requirement) do
    report_id = "report_#{simulation_id}_#{:os.system_time(:millisecond)}"

    with {:ok, outline} <- OutlinePlanner.plan(simulation_id, graph_id, simulation_requirement),
         {:ok, sections_content} <-
           generate_all_sections(outline, simulation_id, graph_id, simulation_requirement) do
      report = assemble_report(outline, sections_content)
      {:ok, report}
    else
      {:error, reason} ->
        ReportLogger.log_error(report_id, inspect(reason), nil)
        {:error, reason}
    end
  end

  @doc """
  Generate report with progress tracking (for LiveView).
  Returns immediately, progress is sent to progress_pid.
  """
  @spec generate_report_with_progress(
          String.t(),
          String.t(),
          String.t(),
          pid()
        ) :: :ok | {:error, term()}
  def generate_report_with_progress(simulation_id, graph_id, requirement, progress_pid)
      when is_pid(progress_pid) do
    spawn(fn ->
      report_id = "report_#{simulation_id}_#{:os.system_time(:millisecond)}"

      ReportProgress.planning_started(report_id)
      ReportLogger.log_planning_start(report_id, simulation_id, requirement)

      case OutlinePlanner.plan(simulation_id, graph_id, requirement) do
        {:ok, outline} ->
          ReportProgress.planning_complete(report_id, length(outline.sections))

          ReportLogger.log_planning_complete(report_id, %{
            title: outline.title,
            sections: outline.sections
          })

          case generate_all_sections_with_progress(
                 outline,
                 simulation_id,
                 graph_id,
                 requirement,
                 progress_pid
               ) do
            {:ok, sections_content} ->
              report = assemble_report(outline, sections_content)
              ReportProgress.complete(report_id)
              ReportLogger.log_report_complete(report_id, length(outline.sections), 0)
              send(progress_pid, {:report_complete, report})

            {:error, reason} ->
              ReportProgress.fail(report_id, inspect(reason))
              ReportLogger.log_error(report_id, inspect(reason), nil)
              send(progress_pid, {:report_error, reason})
          end

        {:error, reason} ->
          ReportProgress.fail(report_id, inspect(reason))
          ReportLogger.log_error(report_id, inspect(reason), nil)
          send(progress_pid, {:report_error, reason})
      end
    end)

    :ok
  end

  @doc """
  Chat with the report agent about the simulation.
  """
  @spec chat(String.t(), String.t(), String.t(), String.t()) :: {:ok, String.t()}
  def chat(simulation_id, graph_id, simulation_requirement, user_message) do
    report_id = "chat_#{simulation_id}"

    messages = [
      %{role: "system", content: chat_system_prompt(simulation_requirement)},
      %{role: "user", content: user_message}
    ]

    collect_chat_response(messages, simulation_id, graph_id, report_id)
  end

  # ============================================================================
  # Section Generation
  # ============================================================================

  defp generate_all_sections(outline, simulation_id, graph_id, simulation_requirement) do
    sections_with_content =
      Enum.map(outline.sections, fn section ->
        section_index = Enum.find_index(outline.sections, &(&1 == section))

        {:ok, content} =
          generate_single_section(
            section,
            outline,
            simulation_id,
            graph_id,
            simulation_requirement
          )

        %{section | content: content}
      end)

    {:ok, sections_with_content}
  rescue
    e -> {:error, inspect(e)}
  end

  defp generate_all_sections_with_progress(
         outline,
         simulation_id,
         graph_id,
         requirement,
         progress_pid
       ) do
    sections_with_content =
      Enum.with_index(outline.sections)
      |> Enum.map(fn {section, idx} ->
        ReportProgress.section_started("report_#{simulation_id}", section.title, idx)

        case generate_single_section(section, outline, simulation_id, graph_id, requirement) do
          {:ok, content} ->
            ReportProgress.section_complete("report_#{simulation_id}", section.title, idx)

            ReportLogger.log_section_complete(
              "report_#{simulation_id}",
              section.title,
              idx,
              content
            )

            send(progress_pid, {:section_complete, idx, section.title})
            %{section | content: content}

          {:error, reason} ->
            ReportProgress.fail("report_#{simulation_id}", inspect(reason))
            %{section | content: "Error generating section: #{inspect(reason)}"}
        end
      end)

    {:ok, sections_with_content}
  rescue
    e -> {:error, inspect(e)}
  end

  defp generate_single_section(section, outline, simulation_id, graph_id, simulation_requirement) do
    previous_content =
      (section.index > 0 && build_previous_sections_context(outline.sections, section.index)) ||
        "(This is the first section)"

    system_prompt =
      section_system_prompt(
        outline.title,
        outline.summary,
        simulation_requirement,
        section.title
      )

    user_prompt =
      section_user_prompt(
        section.title,
        previous_content
      )

    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_prompt}
    ]

    react_loop(messages, section.title, simulation_id, graph_id, 0)
  end

  defp build_previous_sections_context(sections, current_index) do
    sections
    |> Enum.take(current_index)
    |> Enum.map(fn s -> "#{s.title}:\n\n#{s.content}" end)
    |> Enum.join("\n\n---\n\n")
    |> String.slice(0, 12000)
  end

  # ============================================================================
  # ReACT Loop
  # ============================================================================

  defp react_loop(messages, section_title, simulation_id, graph_id, tool_count) do
    case Openrouter.chat(messages, "openai/gpt-4o-mini") do
      {:ok, %{content: content}} ->
        content = String.trim(content)
        ReportLogger.log_llm_response(simulation_id, content)

        {has_tool_call, tool_name, tool_args} = parse_tool_call(content)

        has_final =
          String.starts_with?(content, "Final Answer:") ||
            String.contains?(content, "\"report\":")

        cond do
          has_tool_call and tool_count < @max_tool_calls_per_section ->
            ReportLogger.log_react_thought(
              simulation_id,
              tool_count + 1,
              extract_thought(content)
            )

            ReportLogger.log_tool_call(simulation_id, tool_name, tool_args)

            result = execute_tool(tool_name, tool_args, simulation_id, graph_id)
            ReportLogger.log_tool_result(simulation_id, tool_name, result)

            new_messages =
              messages ++
                [
                  %{role: "assistant", content: content},
                  %{
                    role: "user",
                    content:
                      "Observation:\n\n#{format_tool_result(tool_name, result)}\n\n#{react_continuation_hint(tool_count + 1, @min_tool_calls_per_section, @max_tool_calls_per_section)}"
                  }
                ]

            react_loop(new_messages, section_title, simulation_id, graph_id, tool_count + 1)

          has_final and tool_count >= @min_tool_calls_per_section ->
            extract_final_content(content)

          has_final ->
            observation =
              "You have only used #{tool_count} tools. Please use at least #{@min_tool_calls_per_section} tools before providing your final answer."

            new_messages = messages ++ [%{role: "user", content: observation}]
            react_loop(new_messages, section_title, simulation_id, graph_id, tool_count)

          tool_count >= @max_tool_calls_per_section ->
            extract_final_content(content)

          true ->
            extract_final_content(content)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_tool_call(content) do
    tool_pattern = ~r/<tool_call>\s*\{(?:"(?:name|tool)"\s*:\s*"([^"]+)"[^}]*)\}/

    case Regex.run(tool_pattern, content) do
      [_, tool_name] ->
        args_pattern = ~r/<tool_call>[^}]*"args"\s*:\s*(\{[^}]+\})[^}]*<\/tool_call>/

        args =
          case Regex.run(args_pattern, content) do
            [_, args_str] ->
              case Jason.decode(args_str) do
                {:ok, m} -> m
                _ -> %{}
              end

            _ ->
              %{}
          end

        {true, tool_name, args}

      _ ->
        json_pattern = ~r/\{"(?:name|tool)"\s*:\s*"([^"]+)"[^}]*\}/

        case Regex.run(json_pattern, content) do
          [_, tool_name] ->
            {true, tool_name, %{}}

          _ ->
            {false, nil, %{}}
        end
    end
  rescue
    _ -> {false, nil, %{}}
  end

  defp extract_thought(content) do
    content
    |> String.replace(~r/<tool_call>.*?<\/tool_call>/s, "")
    |> String.replace(~s/Final Answer:/, "")
    |> String.trim()
  end

  defp extract_final_content(content) do
    content
    |> String.replace(~s/Final Answer:/, "")
    |> String.replace(~s/{"report":"/, "")
    |> String.trim()
    |> String.trim_trailing("}")
    |> String.trim()
    |> String.trim(~s/"/)
    |> String.trim()
  end

  defp format_tool_result(_tool_name, {:ok, result}) do
    result_str =
      case result do
        s when is_binary(s) -> s
        m when is_map(m) -> inspect(m, limit: 2000)
        l when is_list(l) -> inspect(l, limit: 2000)
        other -> inspect(other, limit: 2000)
      end

    result_str
  end

  defp format_tool_result(_tool_name, {:error, reason}) do
    "Error: #{inspect(reason)}"
  end

  defp react_continuation_hint(tool_count, min_tools, max_tools) do
    """
    Tools used: #{tool_count}/#{max_tools} (minimum: #{min_tools})
    #{if tool_count < min_tools, do: "Please continue using tools to gather more information.", else: "If you have gathered sufficient information, provide your Final Answer."}
    """
  end

  # ============================================================================
  # Tool Execution
  # ============================================================================

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
    GraphSearch.get_relation_chains(graph_id, args["entity"] || "", depth: args["depth"] || 3)
  end

  defp execute_tool("interview_agents", args, simulation_id, _graph_id) do
    GraphSearch.interview_agents(simulation_id, args["interview_topic"] || "",
      max_agents: args["max_agents"] || 5
    )
  end

  defp execute_tool(tool, args, _simulation_id, _graph_id) do
    {:error, "Unknown tool: #{tool} with args: #{inspect(args)}"}
  end

  # ============================================================================
  # Chat
  # ============================================================================

  defp collect_chat_response(messages, simulation_id, graph_id, report_id, tool_count \\ 0)

  defp collect_chat_response(messages, simulation_id, graph_id, report_id, tool_count)
       when tool_count < 2 do
    case Openrouter.chat(messages, "openai/gpt-4o-mini") do
      {:ok, %{content: content}} ->
        content = String.trim(content)
        ReportLogger.log_llm_response(report_id, content)

        {has_tool_call, tool_name, tool_args} = parse_tool_call(content)

        if has_tool_call do
          result = execute_tool(tool_name, tool_args, simulation_id, graph_id)
          ReportLogger.log_tool_result(report_id, tool_name, result)

          new_messages =
            messages ++
              [
                %{role: "assistant", content: content},
                %{role: "user", content: "Tool result: #{inspect(result)}"}
              ]

          collect_chat_response(new_messages, simulation_id, graph_id, report_id, tool_count + 1)
        else
          {:ok, content}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp collect_chat_response(messages, _simulation_id, _graph_id, _report_id, _tool_count) do
    last_message = List.last(messages)
    {:ok, last_message.content}
  end

  # ============================================================================
  # Prompts
  # ============================================================================

  defp section_system_prompt(report_title, report_summary, simulation_requirement, section_title) do
    """
    You are an expert at writing future prediction reports, working on a single section.

    Report Title: #{report_title}
    Report Summary: #{report_summary}
    Prediction Scenario (simulation requirement): #{simulation_requirement}

    Current Section: #{section_title}

    ========================================================================
    CORE CONCEPT
    ========================================================================

    The simulation world is a preview of the future. We have injected specific conditions (simulation requirements) into the simulation world.
    Agent behaviors and interactions in the simulation are predictions of future group behavior.

    Your task:
    - Reveal what happens in the future under the set conditions
    - Predict how various groups (agents) react and act
    - Discover noteworthy future trends, risks, and opportunities

    DO NOT write analysis of the current real-world situation.
    FOCUS on "what will happen in the future" - simulation results are predictions of the future.

    ========================================================================
    MOST IMPORTANT RULES - MUST FOLLOW
    ========================================================================

    1. You MUST use tools to observe the simulation world
       - You are observing a preview of the future from a "god's eye view"
       - All content must come from events and agent actions in the simulation world
       - DO NOT use your own knowledge to write report content
       - Each section must use at least 3 tools (maximum 5) to observe the simulation

    2. You MUST quote original agent actions and statements
       - Agent statements and behaviors are predictions of future group behavior
       - Use quotes to show these predictions, e.g.:
         > "Certain group will say: original content..."
       - These quotes are core evidence of simulation predictions

    3. Language consistency - quoted content must be translated to report language
       - Tool-returned content may be in English or mixed Chinese/English
       - If simulation requirements and source material are in Chinese, report must be in Chinese
       - When quoting English or mixed content, translate to smooth Chinese first
       - This applies to both body text and quote blocks ( > format)

    4. Faithfully present prediction results
       - Report content must reflect simulation world results representing the future
       - Do not add information that does not exist in the simulation
       - If certain information is lacking, state it honestly

    ========================================================================
    FORMAT RULES - VERY IMPORTANT!
    ========================================================================

    ONE SECTION = MINIMUM CONTENT UNIT
    - Each section is the minimum unit of report content
    - DO NOT use any Markdown headings (#, ##, ###, ####) within sections
    - DO NOT add the section title at the beginning
    - Section titles are added automatically by the system

    Correct example:
    ```
    This section analyzes the public opinion spread trend. Through deep analysis of simulation data, we found...

    **Initial Trigger Phase**

    Weibo served as the first scene for public opinion, bearing the core function of information release:

    > "Weibo contributed 68% of initial mentions..."

    **Sentiment Amplification Phase**

    Other platforms further amplified the event's impact:
    - Strong visual impact
    - High emotional resonance
    ```

    Error example:
    ```
    ## Executive Summary      <- WRONG! Don't add any headings
    ### First Phase           <- WRONG! Don't use ### for subsections
    #### 1.1 Detailed Analysis <- WRONG! Don't use ####

    This section analyzes...
    ```

    ========================================================================
    Available Tools
    ========================================================================

    #{@tools_description}

    ========================================================================
    Workflow
    ========================================================================

    Each reply you can only do ONE of the following (not both):

    Option A - Call a tool:
    Output your thinking, then call a tool using this format:
    <tool_call>{"name": "tool_name", "args": {"arg1": "value1"}}</tool_call>

    Option B - Output final content:
    When you have gathered enough information with at least #{@min_tool_calls_per_section} tool calls, output section content starting with "Final Answer:"

    Strictly prohibited:
    - Including both tool calls and Final Answer in one reply
    - Making up tool return results yourself
    - Calling more than one tool per reply

    ========================================================================
    Section Content Requirements
    ========================================================================

    1. Content must be based on simulation data retrieved via tools
    2. Extensively quote source materials to demonstrate simulation effects
    3. Use Markdown format (but NO headings):
       - Use **bold** for emphasis (instead of subheadings)
       - Use lists (- or 1.2.3.) to organize points
       - Use blank lines to separate paragraphs
       - DO NOT use #, ##, ###, #### or any heading syntax
    4. Quote format must be standalone paragraphs with blank lines before and after
    5. Maintain logical coherence with other sections
    6. AVOID REPETITION - carefully read completed section content above
    7. REITERATE - Do not add any titles!
    """
  end

  defp section_user_prompt(section_title, previous_content) do
    """
    Completed sections (please read carefully to avoid repetition):
    #{previous_content}

    ========================================================================
    CURRENT TASK: Write section: #{section_title}
    ========================================================================

    IMPORTANT REMINDERS:
    1. Carefully read completed sections above to avoid repeating the same information!
    2. You MUST call at least #{@min_tool_calls_per_section} tools before providing final answer
    3. Please mix different tools, don't just use one type
    4. Report content must come from retrieval results, not your own knowledge
    5. All content must be in Chinese (including quotes - translate if needed)

    FORMAT WARNINGS - MUST FOLLOW:
    - DO NOT write any headings (#, ##, ###, ####)
    - DO NOT write "#{section_title}" as the opening
    - Section title is added automatically by the system
    - Write body text directly, use **bold** instead of subheadings

    Please start:
    1. First think (Thought) about what information this section needs
    2. Then call a tool (Action) to retrieve simulation data
    3. After gathering enough information, output Final Answer: with section content (no headings)
    """
  end

  defp chat_system_prompt(simulation_requirement) do
    """
    You are a concise and efficient simulation prediction assistant.

    Background:
    Prediction condition: #{simulation_requirement}

    Rules:
    1. Prioritize answering questions based on simulation prediction results
    2. Answer directly, avoid lengthy thinking or lengthy explanations
    3. Only call tools when report content is insufficient to answer
    4. Answers should be concise, clear, and well-organized

    Available tools:
    #{@tools_description}

    Answer format:
    - Concise and direct, no lengthy text
    - Use > format to quote key content
    - Prioritize giving conclusions, then explain reasons
    """
  end

  # ============================================================================
  # Report Assembly
  # ============================================================================

  defp assemble_report(outline, sections) do
    header = """
    # #{outline.title}

    > #{outline.summary}

    """

    sections_md =
      sections
      |> Enum.filter(&(&1.content && &1.content != ""))
      |> Enum.map(fn section ->
        "## #{section.title}\n\n#{section.content}"
      end)
      |> Enum.join("\n\n")

    header <> sections_md
  end
end
