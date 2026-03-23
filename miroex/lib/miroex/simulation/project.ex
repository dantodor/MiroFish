defmodule Miroex.Simulation.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "projects" do
    field(:name, :string)

    field(:status, Ecto.Enum,
      values: [:created, :ontology_generated, :graph_building, :graph_completed, :failed],
      default: :created
    )

    field(:files, {:array, :map}, default: [])
    field(:total_text_length, :integer, default: 0)
    field(:ontology, :map, default: %{entity_types: [], edge_types: []})
    field(:analysis_summary, :string)
    field(:graph_id, :string)
    field(:simulation_requirement, :string)
    field(:chunk_size, :integer, default: 1000)
    field(:chunk_overlap, :integer, default: 200)
    field(:error, :string)

    belongs_to(:user, Miroex.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :name,
      :status,
      :files,
      :total_text_length,
      :ontology,
      :analysis_summary,
      :graph_id,
      :simulation_requirement,
      :chunk_size,
      :chunk_overlap,
      :error,
      :user_id
    ])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 255)
  end
end
