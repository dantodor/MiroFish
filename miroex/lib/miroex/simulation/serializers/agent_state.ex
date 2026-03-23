defmodule Miroex.Simulation.Serializers.AgentState do
  @moduledoc """
  Serializes Agent state for persistence.
  """

  @doc """
  Serialize an agent state map to a JSON-friendly map.
  """
  @spec serialize(map()) :: map()
  def serialize(agent_state) when is_map(agent_state) do
    %{
      agent_id: agent_state.agent_id,
      name: agent_state.name,
      persona: agent_state.persona,
      platform: Atom.to_string(agent_state.platform),
      memory: agent_state.memory || [],
      state: Atom.to_string(agent_state.state),
      config: agent_state.config || %{},
      simulation_id: agent_state.simulation_id
    }
  end

  @doc """
  Deserialize a map back to an agent state.
  """
  @spec deserialize(map()) :: map()
  def deserialize(data) when is_map(data) do
    %{
      agent_id: data.agent_id,
      name: data.name,
      persona: data.persona,
      platform: String.to_existing_atom(data.platform),
      memory: data.memory || [],
      state: String.to_existing_atom(data.state),
      config: data.config || %{},
      simulation_id: data.simulation_id
    }
  end
end
