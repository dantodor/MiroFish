defmodule Miroex.SimulationFixtures do
  @moduledoc """
  Fixtures for simulation testing.
  """

  def project_fixture(attrs \\ %{}) do
    user = attrs[:user] || Miroex.AccountsFixtures.user_fixture()
    user_id = attrs[:user_id] || user.id

    {:ok, project} =
      attrs
      |> Enum.into(%{
        name: "Test Project",
        status: :created,
        user_id: user_id
      })
      |> Miroex.Simulation.create_project(user_id)

    project
  end

  def simulation_fixture(attrs \\ %{}) do
    project = attrs[:project] || project_fixture(attrs)
    user_id = attrs[:user_id] || project.user_id

    {:ok, simulation} =
      attrs
      |> Enum.into(%{
        name: "Test Simulation",
        project_id: project.id,
        user_id: user_id
      })
      |> Miroex.Simulation.create_simulation(user_id)

    simulation
  end

  def action_fixture(attrs \\ %{}) do
    simulation = attrs[:simulation] || simulation_fixture()

    {:ok, action} =
      attrs
      |> Enum.into(%{
        action_type: :create_post,
        agent_id: 1,
        agent_name: "TestAgent",
        platform: :twitter,
        content: "Test post content",
        simulation_id: simulation.id
      })
      |> Miroex.Simulation.create_action()

    action
  end

  def report_fixture(attrs \\ %{}) do
    user = attrs[:user] || Miroex.AccountsFixtures.user_fixture()
    simulation = attrs[:simulation] || simulation_fixture(user_id: user.id)

    {:ok, report} =
      attrs
      |> Enum.into(%{
        name: "Test Report",
        simulation_id: simulation.id,
        user_id: user.id
      })
      |> Miroex.Reports.create_report(user.id)

    report
  end
end
