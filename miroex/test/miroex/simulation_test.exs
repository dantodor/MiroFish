defmodule Miroex.SimulationTest do
  use Miroex.DataCase

  alias Miroex.Simulation
  alias Miroex.SimulationFixtures

  describe "projects" do
    alias Miroex.Simulation.Project

    test "list_projects/1 returns all projects for a user" do
      user = Miroex.AccountsFixtures.user_fixture()
      project1 = SimulationFixtures.project_fixture(user_id: user.id)
      project2 = SimulationFixtures.project_fixture(user_id: user.id)

      projects = Simulation.list_projects(user.id)
      assert length(projects) >= 2
      assert Enum.any?(projects, fn p -> p.id == project1.id end)
      assert Enum.any?(projects, fn p -> p.id == project2.id end)
    end

    test "get_project!/2 returns the project with given id" do
      project = SimulationFixtures.project_fixture()
      found = Simulation.get_project!(project.id, project.user_id)
      assert found.id == project.id
      assert found.name == project.name
    end

    test "get_project!/2 raises error for invalid id" do
      assert_raise Ecto.NoResultsError, fn ->
        Simulation.get_project!(Ecto.UUID.generate(), 9999)
      end
    end

    test "create_project/2 with valid data creates a project" do
      user = Miroex.AccountsFixtures.user_fixture()
      attrs = %{name: "New Project", status: :created}

      {:ok, project} = Simulation.create_project(attrs, user.id)

      assert project.name == "New Project"
      assert project.status == :created
    end

    test "create_project/2 with invalid data returns error changeset" do
      user = Miroex.AccountsFixtures.user_fixture()
      attrs = %{name: ""}
      {:error, changeset} = Simulation.create_project(attrs, user.id)

      assert "can't be blank" in errors_on(changeset).name
    end

    test "update_project/2 with valid data updates the project" do
      project = SimulationFixtures.project_fixture()

      {:ok, updated} = Simulation.update_project(project, %{name: "Updated Name"})

      assert updated.name == "Updated Name"
    end

    test "delete_project/1 deletes the project" do
      project = SimulationFixtures.project_fixture()
      {:ok, _} = Simulation.delete_project(project)

      assert_raise Ecto.NoResultsError, fn ->
        Simulation.get_project!(project.id, project.user_id)
      end
    end
  end

  describe "simulations" do
    test "list_simulations/1 returns all simulations for a user" do
      user = Miroex.AccountsFixtures.user_fixture()
      sim1 = SimulationFixtures.simulation_fixture(user_id: user.id)
      sim2 = SimulationFixtures.simulation_fixture(user_id: user.id)

      sims = Simulation.list_simulations(user.id)
      assert length(sims) >= 2
    end

    test "get_simulation!/2 returns the simulation with given id" do
      sim = SimulationFixtures.simulation_fixture()
      found = Simulation.get_simulation!(sim.id, sim.user_id)
      assert found.id == sim.id
    end

    test "create_simulation/2 with valid data creates a simulation" do
      project = SimulationFixtures.project_fixture()
      attrs = %{name: "New Sim", project_id: project.id}

      {:ok, sim} = Simulation.create_simulation(attrs, project.user_id)

      assert sim.name == "New Sim"
      assert sim.status == :created
    end

    test "update_simulation/2 with valid data updates the simulation" do
      sim = SimulationFixtures.simulation_fixture()

      {:ok, updated} = Simulation.update_simulation(sim, %{status: :running})

      assert updated.status == :running
    end

    test "delete_simulation/1 deletes the simulation" do
      sim = SimulationFixtures.simulation_fixture()
      {:ok, _} = Simulation.delete_simulation(sim)

      assert_raise Ecto.NoResultsError, fn ->
        Simulation.get_simulation!(sim.id, sim.user_id)
      end
    end
  end

  describe "actions" do
    alias Miroex.Simulation.Action

    test "list_actions/1 returns all actions for a simulation" do
      action = SimulationFixtures.action_fixture()

      actions = Simulation.list_actions(action.simulation_id)
      assert length(actions) >= 1
      assert hd(actions).content == "Test post content"
    end

    test "create_action/1 with valid data creates an action" do
      sim = SimulationFixtures.simulation_fixture()

      attrs = %{
        action_type: :create_post,
        agent_id: 1,
        agent_name: "TestAgent",
        platform: :twitter,
        content: "New post",
        simulation_id: sim.id
      }

      {:ok, action} = Simulation.create_action(attrs)

      assert action.content == "New post"
      assert action.action_type == :create_post
    end

    test "create_actions/1 bulk inserts actions" do
      sim = SimulationFixtures.simulation_fixture()

      attrs_list = [
        %{
          action_type: :create_post,
          agent_id: 1,
          platform: :twitter,
          simulation_id: sim.id,
          content: "Post 1",
          agent_name: "Agent1"
        },
        %{
          action_type: :like_post,
          agent_id: 2,
          platform: :twitter,
          simulation_id: sim.id,
          agent_name: "Agent2"
        }
      ]

      {count, _} = Simulation.create_actions(attrs_list)
      assert count == 2
    end
  end

  describe "tasks" do
    alias Miroex.Simulation.Task

    test "get_task/1 returns task by task_id" do
      project = SimulationFixtures.project_fixture()
      task_id = Ecto.UUID.generate()

      {:ok, task} =
        Simulation.create_task(
          %{
            task_id: task_id,
            task_type: :ontology_generation,
            project_id: project.id
          },
          project.user_id
        )

      found = Simulation.get_task(task_id)
      assert found.id == task.id
    end

    test "update_task_progress/3 updates progress" do
      project = SimulationFixtures.project_fixture()

      {:ok, task} =
        Simulation.create_task(
          %{
            task_type: :graph_build,
            project_id: project.id
          },
          project.user_id
        )

      {:ok, updated} = Simulation.update_task_progress(task.task_id, 50, "Half done")

      assert updated.progress == 50
      assert updated.message == "Half done"
    end

    test "complete_task/2 marks task as completed" do
      project = SimulationFixtures.project_fixture()

      {:ok, task} =
        Simulation.create_task(
          %{
            task_type: :profile_generation,
            project_id: project.id
          },
          project.user_id
        )

      {:ok, completed} = Simulation.complete_task(task.task_id, %{result: "data"})

      assert completed.status == :completed
      assert completed.progress == 100
    end

    test "fail_task/2 marks task as failed" do
      project = SimulationFixtures.project_fixture()

      {:ok, task} =
        Simulation.create_task(
          %{
            task_type: :simulation_run,
            project_id: project.id
          },
          project.user_id
        )

      {:ok, failed} = Simulation.fail_task(task.task_id, "Something went wrong")

      assert failed.status == :failed
      assert failed.error == "Something went wrong"
    end
  end

  describe "interviews" do
    alias Miroex.Simulation.Interview

    test "list_interviews/1 returns all interviews for a simulation" do
      simulation = SimulationFixtures.simulation_fixture()
      user = Miroex.AccountsFixtures.user_fixture(id: simulation.user_id)

      {:ok, interview1} =
        Simulation.create_interview(
          %{
            simulation_id: simulation.id,
            agent_id: 1,
            agent_name: "Agent 1",
            question: "What did you do?",
            response: "I posted something"
          },
          user.id
        )

      {:ok, interview2} =
        Simulation.create_interview(
          %{
            simulation_id: simulation.id,
            agent_id: 2,
            agent_name: "Agent 2",
            question: "What do you think?",
            response: "I think it's great"
          },
          user.id
        )

      interviews = Simulation.list_interviews(simulation.id)
      assert length(interviews) >= 2
      assert Enum.any?(interviews, fn i -> i.id == interview1.id end)
      assert Enum.any?(interviews, fn i -> i.id == interview2.id end)
    end

    test "list_interviews_by_agent/2 returns interviews for specific agent" do
      simulation = SimulationFixtures.simulation_fixture()
      user = Miroex.AccountsFixtures.user_fixture(id: simulation.user_id)

      {:ok, _interview1} =
        Simulation.create_interview(
          %{
            simulation_id: simulation.id,
            agent_id: 1,
            agent_name: "Agent 1",
            question: "Question 1?",
            response: "Response 1"
          },
          user.id
        )

      {:ok, _interview2} =
        Simulation.create_interview(
          %{
            simulation_id: simulation.id,
            agent_id: 1,
            agent_name: "Agent 1",
            question: "Question 2?",
            response: "Response 2"
          },
          user.id
        )

      {:ok, _interview3} =
        Simulation.create_interview(
          %{
            simulation_id: simulation.id,
            agent_id: 2,
            agent_name: "Agent 2",
            question: "Question 3?",
            response: "Response 3"
          },
          user.id
        )

      agent1_interviews = Simulation.list_interviews_by_agent(simulation.id, 1)
      assert length(agent1_interviews) >= 2

      agent2_interviews = Simulation.list_interviews_by_agent(simulation.id, 2)
      assert length(agent2_interviews) >= 1
    end

    test "create_interview/2 with valid data creates an interview" do
      simulation = SimulationFixtures.simulation_fixture()
      user = Miroex.AccountsFixtures.user_fixture(id: simulation.user_id)

      attrs = %{
        simulation_id: simulation.id,
        agent_id: 1,
        agent_name: "Test Agent",
        question: "What is your opinion?",
        response: "My opinion is..."
      }

      {:ok, interview} = Simulation.create_interview(attrs, user.id)

      assert interview.agent_id == 1
      assert interview.agent_name == "Test Agent"
      assert interview.question == "What is your opinion?"
      assert interview.response == "My opinion is..."
    end

    test "create_interview/2 with invalid data returns error changeset" do
      simulation = SimulationFixtures.simulation_fixture()
      user = Miroex.AccountsFixtures.user_fixture(id: simulation.user_id)

      attrs = %{
        simulation_id: simulation.id,
        agent_id: 1,
        question: ""
      }

      {:error, changeset} = Simulation.create_interview(attrs, user.id)

      assert "can't be blank" in errors_on(changeset).question
    end
  end
end
