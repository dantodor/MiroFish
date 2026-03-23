defmodule Miroex.Simulation.Interview do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "interviews" do
    field(:agent_id, :integer)
    field(:agent_name, :string)
    field(:question, :string)
    field(:response, :string)

    belongs_to(:simulation, Miroex.Simulation.Simulation, type: :binary_id)
    belongs_to(:user, Miroex.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(interview, attrs) do
    interview
    |> cast(attrs, [
      :agent_id,
      :agent_name,
      :question,
      :response,
      :simulation_id,
      :user_id
    ])
    |> validate_required([:agent_id, :question, :simulation_id, :user_id])
    |> validate_length(:question, min: 1)
  end
end
