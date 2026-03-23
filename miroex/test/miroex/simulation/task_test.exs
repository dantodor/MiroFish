defmodule Miroex.Simulation.TaskTest do
  use ExUnit.Case, async: true
  use Miroex.DataCase

  alias Miroex.Simulation.Task

  test "changeset with valid data" do
    attrs = %{
      task_id: Ecto.UUID.generate(),
      task_type: :ontology_generation,
      project_id: Ecto.UUID.generate(),
      user_id: 1
    }

    changeset = Task.changeset(%Task{}, attrs)
    assert changeset.valid?
    assert changeset.changes.task_type == :ontology_generation
  end

  test "changeset requires essential fields" do
    attrs = %{}
    changeset = Task.changeset(%Task{}, attrs)
    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).task_id
    assert "can't be blank" in errors_on(changeset).task_type
    assert "can't be blank" in errors_on(changeset).project_id
    assert "can't be blank" in errors_on(changeset).user_id
  end

  test "changeset with optional fields" do
    attrs = %{
      task_id: Ecto.UUID.generate(),
      task_type: :graph_build,
      project_id: Ecto.UUID.generate(),
      user_id: 1,
      progress: 50,
      message: "Building graph...",
      status: :processing
    }

    changeset = Task.changeset(%Task{}, attrs)
    assert changeset.valid?
    assert changeset.changes.progress == 50
    assert changeset.changes.message == "Building graph..."
  end
end
