defmodule Miroex.Repo.Migrations.CreateInterviewsTable do
  use Ecto.Migration

  def change do
    create table(:interviews, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:agent_id, :integer, null: false)
      add(:agent_name, :string)
      add(:question, :text, null: false)
      add(:response, :text)

      add(:simulation_id, references(:simulations, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:user_id, references(:users, type: :bigint, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:interviews, [:simulation_id]))
    create(index(:interviews, [:agent_id]))
    create(index(:interviews, [:user_id]))
  end
end
