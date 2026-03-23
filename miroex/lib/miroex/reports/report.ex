defmodule Miroex.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "reports" do
    field(:name, :string)
    field(:status, Ecto.Enum, values: [:generating, :completed, :failed], default: :generating)
    field(:full_report, :string)
    field(:sections, {:array, :map}, default: [])
    field(:progress, :integer, default: 0)
    field(:error, :string)

    belongs_to(:simulation, Miroex.Simulation.Simulation, type: :binary_id)
    belongs_to(:user, Miroex.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :name,
      :status,
      :full_report,
      :sections,
      :progress,
      :error,
      :simulation_id,
      :user_id
    ])
    |> validate_required([:name, :simulation_id, :user_id])
    |> validate_length(:name, min: 1, max: 255)
  end
end
