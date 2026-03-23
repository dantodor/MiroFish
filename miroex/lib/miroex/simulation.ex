defmodule Miroex.Simulation do
  @moduledoc """
  The Simulation context.
  """
  import Ecto.Query, warn: false
  alias Miroex.Repo
  alias Miroex.Simulation.{Project, Simulation, Action, Task, Interview}

  def list_projects(user_id) do
    Repo.all(from(p in Project, where: p.user_id == ^user_id, order_by: [desc: p.inserted_at]))
  end

  def get_project!(id, user_id) do
    Repo.one!(from(p in Project, where: p.id == ^id and p.user_id == ^user_id))
  end

  def get_project(id) do
    Repo.get(Project, id)
  end

  def create_project(attrs, user_id) do
    attrs = Map.put(attrs, :user_id, user_id)

    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  def list_simulations(user_id) do
    Repo.all(from(s in Simulation, where: s.user_id == ^user_id, order_by: [desc: s.inserted_at]))
  end

  def list_simulations_by_project(project_id) do
    Repo.all(
      from(s in Simulation, where: s.project_id == ^project_id, order_by: [desc: s.inserted_at])
    )
  end

  def get_simulation!(id, user_id) do
    Repo.one!(from(s in Simulation, where: s.id == ^id and s.user_id == ^user_id))
  end

  def get_simulation(id) do
    Repo.get(Simulation, id)
  end

  def create_simulation(attrs, user_id) do
    attrs = Map.put(attrs, :user_id, user_id)

    %Simulation{}
    |> Simulation.changeset(attrs)
    |> Repo.insert()
  end

  def update_simulation(%Simulation{} = simulation, attrs) do
    simulation
    |> Simulation.changeset(attrs)
    |> Repo.update()
  end

  def delete_simulation(%Simulation{} = simulation) do
    Repo.delete(simulation)
  end

  def list_actions(simulation_id) do
    Repo.all(
      from(a in Action,
        where: a.simulation_id == ^simulation_id,
        order_by: [asc: a.round, asc: a.inserted_at]
      )
    )
  end

  def create_action(attrs) do
    %Action{}
    |> Action.changeset(attrs)
    |> Repo.insert()
  end

  def create_actions(attrs_list) when is_list(attrs_list) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs_list =
      Enum.map(attrs_list, fn attrs ->
        Map.merge(attrs, %{inserted_at: now, updated_at: now})
      end)

    Repo.insert_all(Action, attrs_list)
  end

  def get_task(task_id) do
    Repo.one(from(t in Task, where: t.task_id == ^task_id))
  end

  def create_task(attrs, user_id) do
    task_id = attrs[:task_id] || Ecto.UUID.generate()
    attrs = Map.merge(attrs, %{task_id: task_id, user_id: user_id})

    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  def update_task_progress(task_id, progress, message \\ nil) do
    task = get_task(task_id)

    if task do
      attrs = %{progress: progress}
      attrs = if message, do: Map.put(attrs, :message, message), else: attrs
      update_task(task, attrs)
    end
  end

  def complete_task(task_id, result) do
    task = get_task(task_id)

    if task do
      update_task(task, %{status: :completed, progress: 100, result: result})
    end
  end

  def fail_task(task_id, error) do
    task = get_task(task_id)

    if task do
      update_task(task, %{status: :failed, error: error})
    end
  end

  def list_interviews(simulation_id) do
    Repo.all(
      from(i in Interview,
        where: i.simulation_id == ^simulation_id,
        order_by: [desc: i.inserted_at]
      )
    )
  end

  def list_interviews_by_agent(simulation_id, agent_id) do
    Repo.all(
      from(i in Interview,
        where: i.simulation_id == ^simulation_id and i.agent_id == ^agent_id,
        order_by: [desc: i.inserted_at]
      )
    )
  end

  def create_interview(attrs, user_id) do
    attrs = Map.put(attrs, :user_id, user_id)

    %Interview{}
    |> Interview.changeset(attrs)
    |> Repo.insert()
  end
end
