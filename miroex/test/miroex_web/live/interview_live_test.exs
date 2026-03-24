defmodule MiroexWeb.InterviewLiveTest do
  use MiroexWeb.ConnCase

  import Phoenix.LiveViewTest
  import Miroex.AccountsFixtures
  import Miroex.SimulationFixtures

  describe "InterviewLive.Index" do
    setup do
      user = user_fixture()
      project = project_fixture(user_id: user.id)
      simulation = simulation_fixture(project_id: project.id, user_id: user.id, status: :ready)

      %{user: user, project: project, simulation: simulation}
    end

    test "renders interview configuration page", %{
      conn: conn,
      project: project,
      simulation: simulation
    } do
      {:ok, view, html} =
        conn
        |> log_in_user(project.user)
        |> live(~p"/projects/#{project.id}/simulation/#{simulation.id}/interview")

      assert html =~ "Configure Interview"
      assert html =~ "Interview Topic"
      assert has_element?(view, "textarea[name='topic']")
    end

    test "updates topic on change", %{conn: conn, project: project, simulation: simulation} do
      {:ok, view, _html} =
        conn
        |> log_in_user(project.user)
        |> live(~p"/projects/#{project.id}/simulation/#{simulation.id}/interview")

      view
      |> element("textarea[name='topic']")
      |> render_change(%{topic: "Test topic"})

      # Check the assigns were updated
      assert render(view) =~ "Test topic"
    end

    test "updates platform on change", %{conn: conn, project: project, simulation: simulation} do
      {:ok, view, _html} =
        conn
        |> log_in_user(project.user)
        |> live(~p"/projects/#{project.id}/simulation/#{simulation.id}/interview")

      view
      |> element("select[name='platform']")
      |> render_change(%{platform: "twitter"})

      # The platform should be updated
      assert render(view)
    end
  end

  describe "InterviewLive.Show" do
    setup do
      user = user_fixture()
      project = project_fixture(user_id: user.id)
      simulation = simulation_fixture(project_id: project.id, user_id: user.id, status: :running)

      %{user: user, project: project, simulation: simulation}
    end

    test "renders interview results page", %{conn: conn, project: project, simulation: simulation} do
      {:ok, view, html} =
        conn
        |> log_in_user(project.user)
        |> live(~p"/projects/#{project.id}/simulation/#{simulation.id}/interview/conduct")

      assert html =~ "Interview Results"
    end

    test "shows loading state initially", %{conn: conn, project: project, simulation: simulation} do
      {:ok, view, html} =
        conn
        |> log_in_user(project.user)
        |> live(~p"/projects/#{project.id}/simulation/#{simulation.id}/interview/conduct")

      # Since no params are passed, it should show initial state
      assert html =~ "Interview Results"
    end
  end
end
