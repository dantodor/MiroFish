defmodule Miroex.ReportsFixtures do
  @moduledoc """
  Fixtures for reports testing.
  """

  def report_fixture(attrs \\ %{}) do
    user = attrs[:user] || Miroex.AccountsFixtures.user_fixture()
    user_id = attrs[:user_id] || user.id

    simulation =
      attrs[:simulation] || Miroex.SimulationFixtures.simulation_fixture(user_id: user_id)

    {:ok, report} =
      attrs
      |> Enum.into(%{
        name: "Test Report",
        simulation_id: simulation.id,
        user_id: user_id
      })
      |> Miroex.Reports.create_report(user_id)

    report
  end
end
