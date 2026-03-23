defmodule Miroex.Simulation.Action do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "actions" do
    field(:action_type, Ecto.Enum,
      values: [:create_post, :like_post, :comment_post, :follow_user, :retweet_post, :reply_post]
    )

    field(:agent_id, :integer)
    field(:agent_name, :string)
    field(:platform, Ecto.Enum, values: [:twitter, :reddit])
    field(:content, :string)
    field(:metadata, :map, default: %{})
    field(:round, :integer)
    field(:timestamp, :utc_datetime)

    belongs_to(:simulation, Miroex.Simulation.Simulation, type: :binary_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(action, attrs) do
    action
    |> cast(attrs, [
      :action_type,
      :agent_id,
      :agent_name,
      :platform,
      :content,
      :metadata,
      :round,
      :timestamp,
      :simulation_id
    ])
    |> validate_required([:action_type, :agent_id, :platform, :simulation_id])
  end
end
