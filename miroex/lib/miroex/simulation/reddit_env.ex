defmodule Miroex.Simulation.RedditEnv do
  @moduledoc """
  Reddit environment - specific implementation.
  """
  alias Miroex.Simulation.Environment

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {Environment, :start_link, [Keyword.put(opts, :platform, :reddit)]},
      type: :worker
    }
  end
end
