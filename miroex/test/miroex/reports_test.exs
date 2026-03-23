defmodule Miroex.ReportsTest do
  use Miroex.DataCase

  alias Miroex.Reports
  alias Miroex.ReportsFixtures

  describe "reports" do
    alias Miroex.Reports.Report

    test "list_reports/1 returns all reports for a user" do
      user = Miroex.AccountsFixtures.user_fixture()
      report1 = ReportsFixtures.report_fixture(user_id: user.id)
      report2 = ReportsFixtures.report_fixture(user_id: user.id)

      reports = Reports.list_reports(user.id)
      assert length(reports) >= 2
    end

    test "get_report!/2 returns the report with given id" do
      report = ReportsFixtures.report_fixture()
      found = Reports.get_report!(report.id, report.user_id)
      assert found.id == report.id
    end

    test "get_report!/2 raises error for invalid id" do
      assert_raise Ecto.NoResultsError, fn ->
        Reports.get_report!(Ecto.UUID.generate(), 9999)
      end
    end

    test "get_report_by_simulation/1 returns report for simulation" do
      report = ReportsFixtures.report_fixture()
      found = Reports.get_report_by_simulation(report.simulation_id)
      assert found.id == report.id
    end

    test "create_report/2 with valid data creates a report" do
      user = Miroex.AccountsFixtures.user_fixture()
      sim = Miroex.SimulationFixtures.simulation_fixture(user_id: user.id)
      attrs = %{name: "New Report", simulation_id: sim.id}

      {:ok, report} = Reports.create_report(attrs, user.id)

      assert report.name == "New Report"
      assert report.status == :generating
    end

    test "update_report/2 with valid data updates the report" do
      report = ReportsFixtures.report_fixture()

      {:ok, updated} =
        Reports.update_report(report, %{status: :completed, full_report: "Report content"})

      assert updated.status == :completed
      assert updated.full_report == "Report content"
    end

    test "delete_report/1 deletes the report" do
      report = ReportsFixtures.report_fixture()
      {:ok, _} = Reports.delete_report(report)

      assert_raise Ecto.NoResultsError, fn ->
        Reports.get_report!(report.id, report.user_id)
      end
    end

    test "add_report_section/2 appends a section" do
      report = ReportsFixtures.report_fixture()

      {:ok, updated} =
        Reports.add_report_section(report.id, %{title: "Section 1", content: "Content"})

      assert length(updated.sections) == 1
      assert hd(updated.sections).title == "Section 1"
    end

    test "set_report_content/2 sets full report and marks completed" do
      report = ReportsFixtures.report_fixture()

      {:ok, updated} = Reports.set_report_content(report.id, "Full report content here")

      assert updated.full_report == "Full report content here"
      assert updated.status == :completed
      assert updated.progress == 100
    end

    test "update_report_progress/2 updates progress" do
      report = ReportsFixtures.report_fixture()

      {:ok, updated} = Reports.update_report_progress(report.id, 75)

      assert updated.progress == 75
    end
  end
end
