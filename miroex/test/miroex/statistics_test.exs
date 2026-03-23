defmodule Miroex.AI.Tools.StatisticsTest do
  use ExUnit.Case, async: true

  alias Miroex.AI.Tools.Statistics

  describe "execute/1" do
    @tag :skip
    test "handles non-existent simulation gracefully" do
      result = Statistics.execute(Ecto.UUID.generate())
      assert match?({:ok, _}, result)
    end
  end
end
