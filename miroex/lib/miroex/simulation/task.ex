defmodule Miroex.Simulation.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "tasks" do
    field(:task_id, :string)

    field(:task_type, Ecto.Enum,
      values: [
        :ontology_generation,
        :graph_build,
        :profile_generation,
        :config_generation,
        :simulation_run,
        :report_generation
      ]
    )

    field(:status, Ecto.Enum,
      values: [:pending, :processing, :completed, :failed],
      default: :pending
    )

    field(:progress, :integer, default: 0)
    field(:message, :string)
    field(:result, :map, default: %{})
    field(:error, :string)
    field(:progress_detail, :map, default: %{})

    belongs_to(:project, Miroex.Simulation.Project, type: :binary_id)
    belongs_to(:user, Miroex.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :task_id,
      :task_type,
      :status,
      :progress,
      :message,
      :result,
      :error,
      :progress_detail,
      :project_id,
      :user_id
    ])
    |> validate_required([:task_id, :task_type, :project_id, :user_id])
  end
end
