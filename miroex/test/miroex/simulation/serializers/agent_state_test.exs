defmodule Miroex.Simulation.Serializers.AgentStateTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.Serializers.AgentState

  describe "serialize/1" do
    test "serializes agent state to map" do
      agent_state = %{
        agent_id: 42,
        name: "TestAgent",
        persona: "A test persona",
        platform: :twitter,
        memory: [
          %{"action" => "create_post", "content" => "Hello world", "agent_name" => "TestAgent"}
        ],
        state: :idle,
        config: %{activity_level: 0.8},
        simulation_id: "sim_123"
      }

      result = AgentState.serialize(agent_state)

      assert result.agent_id == 42
      assert result.name == "TestAgent"
      assert result.persona == "A test persona"
      assert result.platform == "twitter"
      assert result.memory == agent_state.memory
      assert result.state == "idle"
      assert result.config == %{activity_level: 0.8}
      assert result.simulation_id == "sim_123"
    end

    test "handles nil memory as empty list" do
      agent_state = %{
        agent_id: 1,
        name: "Test",
        persona: "Persona",
        platform: :reddit,
        memory: nil,
        state: :thinking,
        config: %{},
        simulation_id: "sim_1"
      }

      result = AgentState.serialize(agent_state)
      assert result.memory == []
    end

    test "handles nil config as empty map" do
      agent_state = %{
        agent_id: 1,
        name: "Test",
        persona: "Persona",
        platform: :twitter,
        memory: [],
        state: :idle,
        config: nil,
        simulation_id: "sim_1"
      }

      result = AgentState.serialize(agent_state)
      assert result.config == %{}
    end
  end

  describe "deserialize/1" do
    test "deserializes map back to agent state" do
      data = %{
        agent_id: 42,
        name: "TestAgent",
        persona: "A test persona",
        platform: "twitter",
        memory: [
          %{"action" => "create_post", "content" => "Hello world"}
        ],
        state: "idle",
        config: %{activity_level: 0.8},
        simulation_id: "sim_123"
      }

      result = AgentState.deserialize(data)

      assert result.agent_id == 42
      assert result.name == "TestAgent"
      assert result.persona == "A test persona"
      assert result.platform == :twitter
      assert result.memory == data.memory
      assert result.state == :idle
      assert result.config == %{activity_level: 0.8}
      assert result.simulation_id == "sim_123"
    end

    test "handles nil memory" do
      data = %{
        agent_id: 1,
        name: "Test",
        persona: "Persona",
        platform: "reddit",
        memory: nil,
        state: "thinking",
        config: nil,
        simulation_id: "sim_1"
      }

      result = AgentState.deserialize(data)
      assert result.memory == []
      assert result.config == %{}
    end
  end
end
