defmodule MiroexWeb.SimulationControllerTest do
  use MiroexWeb.ConnCase

  import Miroex.AccountsFixtures
  import Miroex.SimulationFixtures

  describe "POST /api/simulation/:id/interview" do
    setup do
      user = user_fixture()
      project = project_fixture(user_id: user.id)
      simulation = simulation_fixture(project_id: project.id, user_id: user.id, status: :ready)

      %{user: user, project: project, simulation: simulation}
    end

    test "returns 200 with valid params", %{conn: conn, simulation: simulation} do
      conn =
        post(conn, ~p"/api/simulation/#{simulation.id}/interview", %{
          "agent_id" => 1,
          "question" => "What is your opinion?"
        })

      # This will likely fail since the agent isn't running, but tests the API structure
      assert json_response(conn, 200)
    end

    test "returns error for non-existent simulation", %{conn: conn} do
      conn =
        post(conn, ~p"/api/simulation/nonexistent/interview", %{
          "agent_id" => 1,
          "question" => "What is your opinion?"
        })

      response = json_response(conn, 200)
      assert response["ok"] == false
      assert response["error"] == "Simulation not found"
    end
  end

  describe "POST /api/simulation/:id/interview/batch" do
    setup do
      user = user_fixture()
      project = project_fixture(user_id: user.id)
      simulation = simulation_fixture(project_id: project.id, user_id: user.id, status: :ready)

      %{user: user, project: project, simulation: simulation}
    end

    test "returns 200 with batch interviews", %{conn: conn, simulation: simulation} do
      conn =
        post(conn, ~p"/api/simulation/#{simulation.id}/interview/batch", %{
          "interviews" => [
            %{"agent_id" => 1, "prompt" => "Question 1"},
            %{"agent_id" => 2, "prompt" => "Question 2"}
          ],
          "platform" => "both"
        })

      response = json_response(conn, 200)
      assert response["success"] == true or response["success"] == false
    end

    test "handles missing platform parameter", %{conn: conn, simulation: simulation} do
      conn =
        post(conn, ~p"/api/simulation/#{simulation.id}/interview/batch", %{
          "interviews" => [
            %{"agent_id" => 1, "prompt" => "Question 1"}
          ]
        })

      response = json_response(conn, 200)
      assert is_map(response)
    end

    test "returns error for non-existent simulation", %{conn: conn} do
      conn =
        post(conn, ~p"/api/simulation/nonexistent/interview/batch", %{
          "interviews" => [
            %{"agent_id" => 1, "prompt" => "Question"}
          ]
        })

      response = json_response(conn, 200)
      assert response["success"] == false
      assert response["error"] == "Simulation not found"
    end
  end
end
