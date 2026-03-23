defmodule Miroex.Reports.ReportProgressTest do
  use ExUnit.Case, async: true

  alias Miroex.Reports.ReportProgress

  describe "start_link/1" do
    test "starts a progress tracker" do
      assert {:ok, pid} = ReportProgress.start_link("test_report_#{:rand.uniform(9999)}")
      assert is_pid(pid)
    end
  end

  describe "get_progress/1" do
    test "returns initial state" do
      report_id = "test_report_get_#{:rand.uniform(9999)}"
      {:ok, _pid} = ReportProgress.start_link(report_id)
      assert {:ok, progress} = ReportProgress.get_progress(report_id)
      assert progress.report_id == report_id
      assert progress.status == :idle
      assert progress.overall_percent == 0
    end
  end

  describe "update/4" do
    test "updates status and progress" do
      report_id = "test_report_update_#{:rand.uniform(9999)}"
      {:ok, _pid} = ReportProgress.start_link(report_id)

      ReportProgress.update(report_id, :generating, "Section 1", 50)

      assert {:ok, progress} = ReportProgress.get_progress(report_id)
      assert progress.status == :generating
      assert progress.current_section == "Section 1"
      assert progress.overall_percent == 50
    end
  end

  describe "planning_started/1" do
    test "sets status to planning" do
      report_id = "test_report_plan_#{:rand.uniform(9999)}"
      {:ok, _pid} = ReportProgress.start_link(report_id)

      ReportProgress.planning_started(report_id)

      assert {:ok, progress} = ReportProgress.get_progress(report_id)
      assert progress.status == :planning
    end
  end

  describe "planning_complete/2" do
    test "updates status and total sections" do
      report_id = "test_report_plan_complete_#{:rand.uniform(9999)}"
      {:ok, _pid} = ReportProgress.start_link(report_id)

      ReportProgress.planning_complete(report_id, 5)

      assert {:ok, progress} = ReportProgress.get_progress(report_id)
      assert progress.status == :generating
      assert progress.total_sections == 5
      assert progress.overall_percent == 10
    end
  end

  describe "section_started/3" do
    test "updates current section info" do
      report_id = "test_report_section_#{:rand.uniform(9999)}"
      {:ok, _pid} = ReportProgress.start_link(report_id)

      ReportProgress.section_started(report_id, "Introduction", 0)

      assert {:ok, progress} = ReportProgress.get_progress(report_id)
      assert progress.current_section == "Introduction"
      assert progress.current_section_index == 0
    end
  end

  describe "section_complete/3" do
    test "increments sections completed and updates percent" do
      report_id = "test_report_section_complete_#{:rand.uniform(9999)}"
      {:ok, _pid} = ReportProgress.start_link(report_id)

      ReportProgress.planning_complete(report_id, 3)
      ReportProgress.section_complete(report_id, "Section 1", 0)

      assert {:ok, progress} = ReportProgress.get_progress(report_id)
      assert progress.sections_completed == 1
      assert progress.overall_percent == 30
    end
  end

  describe "complete/1" do
    test "sets status to completed and percent to 100" do
      report_id = "test_report_complete_#{:rand.uniform(9999)}"
      {:ok, _pid} = ReportProgress.start_link(report_id)

      ReportProgress.complete(report_id)

      assert {:ok, progress} = ReportProgress.get_progress(report_id)
      assert progress.status == :completed
      assert progress.overall_percent == 100
      assert progress.completed_at != nil
    end
  end

  describe "fail/2" do
    test "sets status to failed with error message" do
      report_id = "test_report_fail_#{:rand.uniform(9999)}"
      {:ok, _pid} = ReportProgress.start_link(report_id)

      ReportProgress.fail(report_id, "Something went wrong")

      assert {:ok, progress} = ReportProgress.get_progress(report_id)
      assert progress.status == :failed
      assert progress.error == "Something went wrong"
    end
  end
end
