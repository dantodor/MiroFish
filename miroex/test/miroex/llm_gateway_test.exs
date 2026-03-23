defmodule Miroex.Simulation.LLMGatewayTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.LLMGateway

  setup do
    LLMGateway.start_link([])
    :ok
  end

  describe "request/1" do
    test "gateway handles requests" do
      messages = [%{role: "user", content: "Hello"}]

      result = LLMGateway.request(messages)

      assert is_tuple(result)
    end
  end
end
