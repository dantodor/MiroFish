defmodule Miroex.Repo.Migrations.CreateSimulationTables do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:name, :string, null: false)
      add(:status, :string, default: "created")
      add(:files, {:array, :map}, default: [])
      add(:total_text_length, :integer, default: 0)
      add(:ontology, :map, default: %{entity_types: [], edge_types: []})
      add(:analysis_summary, :text)
      add(:graph_id, :string)
      add(:simulation_requirement, :text)
      add(:chunk_size, :integer, default: 1000)
      add(:chunk_overlap, :integer, default: 200)
      add(:error, :text)
      add(:user_id, references(:users, type: :bigint), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:projects, [:user_id]))
    create(index(:projects, [:status]))

    create table(:simulations, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:name, :string, null: false)
      add(:status, :string, default: "created")
      add(:enable_twitter, :boolean, default: true)
      add(:enable_reddit, :boolean, default: false)
      add(:graph_id, :string)
      add(:entities_count, :integer, default: 0)
      add(:profiles_count, :integer, default: 0)
      add(:entity_types, {:array, :string}, default: [])
      add(:config_generated, :boolean, default: false)
      add(:current_round, :integer, default: 0)
      add(:total_rounds, :integer, default: 72)
      add(:twitter_status, :string)
      add(:reddit_status, :string)
      add(:config, :map, default: %{})
      add(:error, :text)
      add(:project_id, references(:projects, type: :uuid, on_delete: :delete_all), null: false)
      add(:user_id, references(:users, type: :bigint, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:simulations, [:project_id]))
    create(index(:simulations, [:user_id]))
    create(index(:simulations, [:status]))

    create table(:actions, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:action_type, :string, null: false)
      add(:agent_id, :integer, null: false)
      add(:agent_name, :string)
      add(:platform, :string, null: false)
      add(:content, :text)
      add(:metadata, :map, default: %{})
      add(:round, :integer)
      add(:timestamp, :utc_datetime)

      add(:simulation_id, references(:simulations, type: :uuid, on_delete: :delete_all),
        null: false
      )

      timestamps(type: :utc_datetime)
    end

    create(index(:actions, [:simulation_id]))
    create(index(:actions, [:agent_id]))
    create(index(:actions, [:platform]))

    create table(:tasks, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:task_id, :string, null: false)
      add(:task_type, :string, null: false)
      add(:status, :string, default: "pending")
      add(:progress, :integer, default: 0)
      add(:message, :text)
      add(:result, :map, default: %{})
      add(:error, :text)
      add(:progress_detail, :map, default: %{})
      add(:project_id, references(:projects, type: :uuid, on_delete: :delete_all), null: false)
      add(:user_id, references(:users, type: :bigint, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:tasks, [:project_id]))
    create(index(:tasks, [:task_id], unique: true))
    create(index(:tasks, [:status]))

    create table(:reports, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:name, :string, null: false)
      add(:status, :string, default: "generating")
      add(:full_report, :text)
      add(:sections, {:array, :map}, default: [])
      add(:progress, :integer, default: 0)
      add(:error, :text)

      add(:simulation_id, references(:simulations, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:user_id, references(:users, type: :bigint, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:reports, [:simulation_id]))
    create(index(:reports, [:user_id]))
    create(index(:reports, [:status]))
  end
end
