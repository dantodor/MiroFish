defmodule Miroex.Simulation.Simulation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "simulations" do
    field(:name, :string)

    field(:status, Ecto.Enum,
      values: [:created, :preparing, :ready, :running, :paused, :completed, :failed],
      default: :created
    )

    field(:enable_twitter, :boolean, default: true)
    field(:enable_reddit, :boolean, default: false)
    field(:graph_id, :string)
    field(:entities_count, :integer, default: 0)
    field(:profiles_count, :integer, default: 0)
    field(:entity_types, {:array, :string}, default: [])
    field(:config_generated, :boolean, default: false)
    field(:current_round, :integer, default: 0)
    field(:total_rounds, :integer, default: 72)
    field(:twitter_status, :string)
    field(:reddit_status, :string)
    field(:config, :map, default: %{})
    field(:error, :string)

    belongs_to(:project, Miroex.Simulation.Project, type: :binary_id)
    belongs_to(:user, Miroex.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(simulation, attrs) do
    simulation
    |> cast(attrs, [
      :name,
      :status,
      :enable_twitter,
      :enable_reddit,
      :graph_id,
      :entities_count,
      :profiles_count,
      :entity_types,
      :config_generated,
      :current_round,
      :total_rounds,
      :twitter_status,
      :reddit_status,
      :config,
      :error,
      :project_id,
      :user_id
    ])
    |> validate_required([:name, :project_id, :user_id])
    |> validate_length(:name, min: 1, max: 255)
  end
end
