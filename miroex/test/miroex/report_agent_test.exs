defmodule Miroex.Reports.ReportAgentTest do
  use ExUnit.Case, async: true

  alias Miroex.Reports.ReportAgent

  describe "generate_report/3" do
    @tag :tmp_dir
    test "handles non-existent simulation gracefully", tmp_dir do
      result =
        ReportAgent.generate_report("nonexistent_sim", "nonexistent_graph", "test requirement")

      assert match?({:error, _}, result)
    end
  end

  describe "chat/4" do
    test "handles non-existent simulation gracefully" do
      result =
        ReportAgent.chat("nonexistent_sim", "nonexistent_graph", "test requirement", "Hello")

      assert match?({:error, _}, result)
    end
  end
end
