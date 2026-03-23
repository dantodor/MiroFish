defmodule Miroex.Simulation.ConfigGeneratorTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.ConfigGenerator

  describe "generate/3" do
    test "handles invalid LLM response gracefully" do
      entities = [%{"name" => "Test", "type" => "Person"}]
      result = ConfigGenerator.generate("Requirements", entities, ["Person"])

      assert match?({:error, _}, result)
    end
  end
end
