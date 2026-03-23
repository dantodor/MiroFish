defmodule Miroex.Reports.ReportTest do
  use ExUnit.Case, async: true
  use Miroex.DataCase

  alias Miroex.Reports.Report

  test "changeset with valid data" do
    attrs = %{
      name: "Test Report",
      simulation_id: Ecto.UUID.generate(),
      user_id: 1
    }

    changeset = Report.changeset(%Report{}, attrs)
    assert changeset.valid?
    assert changeset.changes.name == "Test Report"
  end

  test "changeset requires essential fields" do
    attrs = %{}
    changeset = Report.changeset(%Report{}, attrs)
    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).name
    assert "can't be blank" in errors_on(changeset).simulation_id
    assert "can't be blank" in errors_on(changeset).user_id
  end

  test "name length validation" do
    attrs = %{
      name: String.duplicate("a", 300),
      simulation_id: Ecto.UUID.generate(),
      user_id: 1
    }

    changeset = Report.changeset(%Report{}, attrs)
    refute changeset.valid?
    assert "should be at most 255 character(s)" in errors_on(changeset).name
  end
end
