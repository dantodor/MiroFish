defmodule Miroex.Simulation.ProfileGeneratorTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.ProfileGenerator

  describe "generate_twitter_profiles/1" do
    test "handles non-existent graph gracefully" do
      result = ProfileGenerator.generate_twitter_profiles("nonexistent_graph")
      assert match?({:error, _}, result)
    end
  end

  describe "generate_reddit_profiles/1" do
    test "handles non-existent graph gracefully" do
      result = ProfileGenerator.generate_reddit_profiles("nonexistent_graph")
      assert match?({:error, _}, result)
    end
  end
end
