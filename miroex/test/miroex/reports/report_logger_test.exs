defmodule Miroex.Reports.ReportLoggerTest do
  use ExUnit.Case, async: false

  alias Miroex.Reports.ReportLogger

  @test_dir "/tmp/miroex_test_logs"

  setup do
    File.mkdir_p!(@test_dir)
    Application.put_env(:miroex, :reports_log_dir, @test_dir)

    on_exit(fn ->
      Application.delete_env(:miroex, :reports_log_dir)
      File.rm_rf(@test_dir)
    end)

    :ok
  end

  describe "log_event/2" do
    test "creates log file with JSON line" do
      :ok = ReportLogger.log_event("test_report_1", %{type: "test", data: "value"})

      path = Path.join([@test_dir, "test_report_1.jsonl"])
      assert File.exists?(path)

      content = File.read!(path)
      assert content =~ ~s("timestamp")
      assert content =~ ~s("type":"test")
      assert content =~ ~s("data":"value")
    end

    test "appends to existing log file" do
      :ok = ReportLogger.log_event("test_report_2", %{type: "first"})
      :ok = ReportLogger.log_event("test_report_2", %{type: "second"})

      path = Path.join([@test_dir, "test_report_2.jsonl"])
      content = File.read!(path)
      lines = String.split(content, "\n", trim: true)
      assert length(lines) >= 2
    end
  end

  describe "log_tool_call/3" do
    test "logs tool call with correct format" do
      :ok =
        ReportLogger.log_tool_call("test_report_3", "graph_search", %{
          "query" => "test query"
        })

      {:ok, logs} = ReportLogger.get_logs("test_report_3")
      assert length(logs) == 1
      assert hd(logs)["event"]["type"] == "tool_call"
      assert hd(logs)["event"]["tool"] == "graph_search"
      assert hd(logs)["event"]["args"] == %{"query" => "test query"}
    end
  end

  describe "log_tool_result/3" do
    test "logs tool result with truncated inspect" do
      large_result = %{data: String.duplicate("x", 2000)}
      :ok = ReportLogger.log_tool_result("test_report_4", "statistics", large_result)

      {:ok, logs} = ReportLogger.get_logs("test_report_4")
      assert length(logs) == 1
      assert hd(logs)["event"]["type"] == "tool_result"
      assert hd(logs)["event"]["tool"] == "statistics"
    end
  end

  describe "log_llm_response/2" do
    test "logs LLM response content" do
      :ok = ReportLogger.log_llm_response("test_report_5", "This is an LLM response")

      {:ok, logs} = ReportLogger.get_logs("test_report_5")
      assert length(logs) == 1
      assert hd(logs)["event"]["type"] == "llm_response"
      assert hd(logs)["event"]["content"] == "This is an LLM response"
    end

    test "truncates very long content" do
      long_content = String.duplicate("a", 6000)
      :ok = ReportLogger.log_llm_response("test_report_6", long_content)

      {:ok, logs} = ReportLogger.get_logs("test_report_6")
      content = hd(logs)["event"]["content"]
      assert String.length(content) <= 5000
    end
  end

  describe "get_logs/1" do
    test "returns empty list for non-existent log" do
      {:ok, logs} = ReportLogger.get_logs("non_existent_report")
      assert logs == []
    end

    test "returns all log entries in order" do
      ReportLogger.log_event("test_report_7", %{order: 1})
      ReportLogger.log_event("test_report_7", %{order: 2})
      ReportLogger.log_event("test_report_7", %{order: 3})

      {:ok, logs} = ReportLogger.get_logs("test_report_7")
      assert length(logs) == 3
    end
  end

  describe "get_logs_by_type/2" do
    test "filters logs by type" do
      ReportLogger.log_tool_call("test_report_8", "graph_search", %{})
      ReportLogger.log_llm_response("test_report_8", "response 1")
      ReportLogger.log_tool_call("test_report_8", "statistics", %{})
      ReportLogger.log_llm_response("test_report_8", "response 2")

      {:ok, tool_calls} = ReportLogger.get_logs_by_type("test_report_8", "tool_call")
      assert length(tool_calls) == 2

      {:ok, llm_responses} = ReportLogger.get_logs_by_type("test_report_8", "llm_response")
      assert length(llm_responses) == 2
    end
  end

  describe "get_tool_calls/1" do
    test "returns only tool call logs" do
      ReportLogger.log_tool_call("test_report_9", "graph_search", %{})
      ReportLogger.log_llm_response("test_report_9", "some response")

      {:ok, tool_calls} = ReportLogger.get_tool_calls("test_report_9")
      assert length(tool_calls) == 1
      assert hd(tool_calls)["event"]["tool"] == "graph_search"
    end
  end

  describe "get_llm_responses/1" do
    test "returns only LLM response logs" do
      ReportLogger.log_llm_response("test_report_10", "first response")
      ReportLogger.log_tool_call("test_report_10", "graph_search", %{})

      {:ok, responses} = ReportLogger.get_llm_responses("test_report_10")
      assert length(responses) == 1
      assert hd(responses)["event"]["content"] == "first response"
    end
  end

  describe "log_step/4" do
    test "logs step with details" do
      :ok = ReportLogger.log_step("test_report_step", 1, "Planning", %{round: 1})

      {:ok, logs} = ReportLogger.get_logs("test_report_step")
      assert length(logs) == 1
      assert hd(logs)["event"]["type"] == "step"
      assert hd(logs)["event"]["step_number"] == 1
      assert hd(logs)["event"]["step_name"] == "Planning"
    end
  end

  describe "log_paragraph/5" do
    test "logs paragraph generation" do
      :ok = ReportLogger.log_paragraph("test_report_para", "Section 1", 0, 0, "Paragraph content")

      {:ok, logs} = ReportLogger.get_logs("test_report_para")
      assert length(logs) == 1
      assert hd(logs)["event"]["type"] == "paragraph"
      assert hd(logs)["event"]["paragraph_index"] == 0
    end
  end

  describe "get_report_stats/1" do
    test "calculates report statistics" do
      report_id = "test_report_stats"

      ReportLogger.log_tool_call(report_id, "tool1", %{})
      ReportLogger.log_tool_call(report_id, "tool2", %{})
      ReportLogger.log_llm_response(report_id, "response")
      ReportLogger.log_section_complete(report_id, "Section", 0, "Content")

      {:ok, stats} = ReportLogger.get_report_stats(report_id)

      assert stats.total_events == 4
      assert stats.tool_calls == 2
      assert stats.llm_responses == 1
      assert stats.sections_generated == 1
      assert "tool1" in stats.tools_used
      assert "tool2" in stats.tools_used
    end

    test "returns zero stats for empty report" do
      {:ok, stats} = ReportLogger.get_report_stats("nonexistent_report")
      assert stats.total_events == 0
      assert stats.tool_calls == 0
    end
  end
end
