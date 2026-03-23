defmodule Miroex.Reports.ReportAgentTest do
  use ExUnit.Case, async: true

  alias Miroex.Reports.ReportAgent

  describe "generate_report/2" do
    test "handles non-existent simulation gracefully" do
      result = ReportAgent.generate_report("nonexistent_sim", "nonexistent_graph")
      assert match?({:error, _}, result)
    end
  end

  describe "chat/4" do
    test "handles non-existent simulation gracefully" do
      result = ReportAgent.chat("nonexistent_sim", "nonexistent_graph", "Hello")
      assert match?({:error, _}, result)
    end
  end
end
