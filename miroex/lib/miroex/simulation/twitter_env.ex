defmodule Miroex.Simulation.TwitterEnv do
  @moduledoc """
  Twitter environment - specific implementation.
  """
  alias Miroex.Simulation.Environment

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {Environment, :start_link, [Keyword.put(opts, :platform, :twitter)]},
      type: :worker
    }
  end
end
