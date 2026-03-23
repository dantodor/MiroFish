defmodule Miroex.Simulation.AgentTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.Agent
  alias Miroex.Simulation.AgentSupervisor

  setup do
    AgentSupervisor.start_link([])
    :ok
  end

  describe "start_link/1" do
    test "starts an agent with valid opts" do
      opts = [
        gen_name: :test_agent_1,
        agent_id: 1,
        name: "TestUser",
        persona: "A test user",
        platform: :twitter,
        simulation_id: "sim_1"
      ]

      {:ok, pid} = Agent.start_link(opts)
      assert is_pid(pid)
    end
  end

  describe "get_state/1" do
    test "returns agent state" do
      opts = [
        gen_name: :test_agent_2,
        agent_id: 2,
        name: "TestUser2",
        persona: "Another test user",
        platform: :reddit,
        simulation_id: "sim_1"
      ]

      {:ok, pid} = Agent.start_link(opts)
      state = Agent.get_state(pid)

      assert state.agent_id == 2
      assert state.name == "TestUser2"
      assert state.persona == "Another test user"
      assert state.platform == :reddit
      assert state.state == :idle
    end
  end

  describe "receive_memory/2" do
    test "adds memory to agent" do
      opts = [
        gen_name: :test_agent_3,
        agent_id: 3,
        name: "TestUser3",
        persona: "Test persona",
        platform: :twitter,
        simulation_id: "sim_1"
      ]

      {:ok, pid} = Agent.start_link(opts)

      memory = [%{"action" => "create_post", "content" => "Hello", "agent_name" => "TestUser3"}]
      Agent.receive_memory(pid, memory)

      state = Agent.get_state(pid)
      assert length(state.memory) == 1
    end

    test "limits memory to 100 items" do
      opts = [
        gen_name: :test_agent_4,
        agent_id: 4,
        name: "TestUser4",
        persona: "Test persona",
        platform: :twitter,
        simulation_id: "sim_1"
      ]

      {:ok, pid} = Agent.start_link(opts)

      memory =
        Enum.map(1..150, fn i ->
          %{"action" => "post", "content" => "Message #{i}"}
        end)

      Agent.receive_memory(pid, memory)

      state = Agent.get_state(pid)
      assert length(state.memory) == 100
    end
  end

  describe "update_config/2" do
    test "updates agent config" do
      opts = [
        gen_name: :test_agent_5,
        agent_id: 5,
        name: "TestUser5",
        persona: "Test persona",
        platform: :twitter,
        simulation_id: "sim_1"
      ]

      {:ok, pid} = Agent.start_link(opts)

      new_config = %{activity_level: 0.8, posts_per_hour: 0.6}
      Agent.update_config(pid, new_config)

      state = Agent.get_state(pid)
      assert state.config[:activity_level] == 0.8
      assert state.config[:posts_per_hour] == 0.6
    end
  end

  describe "decide_action/1" do
    test "returns :thinking immediately" do
      opts = [
        gen_name: :test_agent_6,
        agent_id: 6,
        name: "TestUser6",
        persona: "Test persona",
        platform: :twitter,
        simulation_id: "sim_1"
      ]

      {:ok, pid} = Agent.start_link(opts)
      result = Agent.decide_action(pid)
      assert result == :thinking
    end
  end
end

defmodule Miroex.Simulation.AgentSupervisorTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.AgentSupervisor

  setup do
    AgentSupervisor.start_link([])
    :ok
  end

  describe "start_agent/1" do
    test "starts an agent as child" do
      opts = [
        gen_name: :sup_test_agent_1,
        agent_id: 1,
        name: "SupTestUser",
        persona: "Test persona",
        platform: :twitter,
        simulation_id: "sim_1"
      ]

      {:ok, pid} = AgentSupervisor.start_agent(opts)
      assert is_pid(pid)
    end
  end

  describe "count_agents/0" do
    test "returns count of supervised agents" do
      opts1 = [
        gen_name: :sup_test_agent_2,
        agent_id: 2,
        name: "User2",
        persona: "Persona",
        platform: :twitter,
        simulation_id: "sim_1"
      ]

      opts2 = [
        gen_name: :sup_test_agent_3,
        agent_id: 3,
        name: "User3",
        persona: "Persona",
        platform: :twitter,
        simulation_id: "sim_1"
      ]

      AgentSupervisor.start_agent(opts1)
      AgentSupervisor.start_agent(opts2)

      counts = AgentSupervisor.count_agents()
      assert counts.active >= 2
    end
  end
end
