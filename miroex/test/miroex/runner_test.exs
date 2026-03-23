defmodule Miroex.Simulation.RunnerTest do
  use ExUnit.Case, async: false

  alias Miroex.Simulation.Runner

  describe "get_simulation_status/1" do
    @tag :skip
    test "handles non-existent simulation gracefully" do
      result = Runner.get_simulation_status("nonexistent_sim_id")
      assert match?({:error, _}, result) or result == :error
    end
  end

  describe "stop_simulation/1" do
    test "handles non-existent simulation gracefully" do
      result = Runner.stop_simulation("nonexistent_sim_id")
      assert result == :ok
    end
  end
end
