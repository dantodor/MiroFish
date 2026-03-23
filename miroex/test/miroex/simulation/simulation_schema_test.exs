defmodule Miroex.Simulation.SimulationTest do
  use Miroex.DataCase

  alias Miroex.Simulation.Simulation

  test "changeset with valid data" do
    attrs = %{name: "Test Simulation", project_id: Ecto.UUID.generate(), user_id: 1}
    changeset = Simulation.changeset(%Simulation{}, attrs)
    assert changeset.valid?
    assert changeset.changes.name == "Test Simulation"
  end

  test "changeset requires name and ids" do
    attrs = %{}
    changeset = Simulation.changeset(%Simulation{}, attrs)
    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).name
    assert "can't be blank" in errors_on(changeset).project_id
    assert "can't be blank" in errors_on(changeset).user_id
  end

  test "changeset with optional fields" do
    attrs = %{
      name: "Test",
      project_id: Ecto.UUID.generate(),
      user_id: 1,
      enable_twitter: false,
      enable_reddit: true,
      current_round: 10,
      total_rounds: 100
    }

    changeset = Simulation.changeset(%Simulation{}, attrs)
    assert changeset.valid?
    assert changeset.changes.enable_twitter == false
    assert changeset.changes.enable_reddit == true
    assert changeset.changes.current_round == 10
  end
end
