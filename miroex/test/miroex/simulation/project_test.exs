defmodule Miroex.Simulation.ProjectTest do
  use ExUnit.Case, async: true
  use Miroex.DataCase

  alias Miroex.Simulation.Project

  test "changeset with valid data" do
    attrs = %{name: "Test Project", user_id: 1}
    changeset = Project.changeset(%Project{}, attrs)
    assert changeset.valid?
    assert changeset.changes.name == "Test Project"
  end

  test "changeset requires name" do
    attrs = %{user_id: 1}
    changeset = Project.changeset(%Project{}, attrs)
    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).name
  end

  test "changeset requires user_id" do
    attrs = %{name: "Test Project"}
    changeset = Project.changeset(%Project{}, attrs)
    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).user_id
  end

  test "changeset with optional fields" do
    attrs = %{
      name: "Test",
      user_id: 1,
      status: :graph_completed,
      ontology: %{entity_types: ["Person"], edge_types: ["knows"]},
      graph_id: "graph_123"
    }

    changeset = Project.changeset(%Project{}, attrs)
    assert changeset.valid?
    assert changeset.changes.status == :graph_completed
    assert changeset.changes.graph_id == "graph_123"
  end

  test "name length validation" do
    attrs = %{name: String.duplicate("a", 300), user_id: 1}
    changeset = Project.changeset(%Project{}, attrs)
    refute changeset.valid?
    assert "should be at most 255 character(s)" in errors_on(changeset).name
  end
end
