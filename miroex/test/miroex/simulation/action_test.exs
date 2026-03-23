defmodule Miroex.Simulation.ActionTest do
  use ExUnit.Case, async: true
  use Miroex.DataCase

  alias Miroex.Simulation.Action

  test "changeset with valid data" do
    attrs = %{
      action_type: :create_post,
      agent_id: 1,
      platform: :twitter,
      simulation_id: Ecto.UUID.generate()
    }

    changeset = Action.changeset(%Action{}, attrs)
    assert changeset.valid?
  end

  test "changeset requires essential fields" do
    attrs = %{}
    changeset = Action.changeset(%Action{}, attrs)
    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).action_type
    assert "can't be blank" in errors_on(changeset).agent_id
    assert "can't be blank" in errors_on(changeset).platform
    assert "can't be blank" in errors_on(changeset).simulation_id
  end

  test "changeset with content" do
    attrs = %{
      action_type: :create_post,
      agent_id: 1,
      platform: :twitter,
      simulation_id: Ecto.UUID.generate(),
      content: "Hello world!"
    }

    changeset = Action.changeset(%Action{}, attrs)
    assert changeset.valid?
    assert changeset.changes.content == "Hello world!"
  end

  test "changeset with metadata" do
    attrs = %{
      action_type: :like_post,
      agent_id: 1,
      platform: :twitter,
      simulation_id: Ecto.UUID.generate(),
      metadata: %{"post_id" => "123"}
    }

    changeset = Action.changeset(%Action{}, attrs)
    assert changeset.valid?
    assert changeset.changes.metadata == %{"post_id" => "123"}
  end
end
