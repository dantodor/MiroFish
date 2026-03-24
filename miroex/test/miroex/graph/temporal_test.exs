defmodule Miroex.Graph.TemporalTest do
  use ExUnit.Case, async: true

  alias Miroex.Graph.Temporal

  describe "create_edge/4" do
    test "creates a temporal edge with current time" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")

      assert edge.from == "Alice"
      assert edge.to == "Bob"
      assert edge.type == "KNOWS"
      assert edge.fact == "Alice knows Bob"
      assert %DateTime{} = edge.created_at
      assert %DateTime{} = edge.valid_at
      assert edge.invalid_at == nil
      assert edge.expired_at == nil
    end

    test "creates a temporal edge with custom valid_from" do
      custom_time = ~U[2024-01-15 10:00:00Z]
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob", custom_time)

      assert edge.valid_at == custom_time
      assert edge.created_at == custom_time
    end
  end

  describe "invalidate/1" do
    test "marks edge as invalid" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      invalid_edge = Temporal.invalidate(edge)

      assert %DateTime{} = invalid_edge.invalid_at
      assert Temporal.valid?(invalid_edge) == false
    end
  end

  describe "expire/1" do
    test "marks edge as expired" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      expired_edge = Temporal.expire(edge)

      assert %DateTime{} = expired_edge.expired_at
      assert Temporal.expired?(expired_edge) == true
    end
  end

  describe "set_validity/3" do
    test "updates validity period" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      valid_from = ~U[2024-01-01 00:00:00Z]
      valid_until = ~U[2024-12-31 23:59:59Z]

      updated = Temporal.set_validity(edge, valid_from, valid_until)

      assert updated.valid_at == valid_from
      assert updated.invalid_at == valid_until
    end
  end

  describe "valid?/1" do
    test "returns true for valid edge" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      assert Temporal.valid?(edge) == true
    end

    test "returns false for invalid edge" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      invalid_edge = Temporal.invalidate(edge)
      assert Temporal.valid?(invalid_edge) == false
    end
  end

  describe "expired?/1" do
    test "returns false for non-expired edge" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      assert Temporal.expired?(edge) == false
    end

    test "returns true for expired edge" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      expired_edge = Temporal.expire(edge)
      assert Temporal.expired?(expired_edge) == true
    end
  end

  describe "valid_at?/2" do
    test "returns true for datetime within validity period" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      check_time = DateTime.utc_now()

      assert Temporal.valid_at?(edge, check_time) == true
    end

    test "returns false for datetime before validity" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      check_time = ~U[2000-01-01 00:00:00Z]

      assert Temporal.valid_at?(edge, check_time) == false
    end

    test "returns false for datetime after invalidation" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      invalid_edge = Temporal.invalidate(edge)
      check_time = DateTime.add(DateTime.utc_now(), 3600, :second)

      assert Temporal.valid_at?(invalid_edge, check_time) == false
    end
  end

  describe "filter_valid/1" do
    test "filters only valid edges" do
      valid_edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Knows")
      invalid_edge = Temporal.invalidate(Temporal.create_edge("Bob", "Charlie", "KNOWS", "Knows"))

      edges = [valid_edge, invalid_edge]
      filtered = Temporal.filter_valid(edges)

      assert length(filtered) == 1
      assert hd(filtered).from == "Alice"
    end
  end

  describe "filter_expired/1" do
    test "filters only expired edges" do
      valid_edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Knows")
      expired_edge = Temporal.expire(Temporal.create_edge("Bob", "Charlie", "KNOWS", "Knows"))

      edges = [valid_edge, expired_edge]
      filtered = Temporal.filter_expired(edges)

      assert length(filtered) == 1
      assert hd(filtered).from == "Bob"
    end
  end

  describe "filter_valid_at/2" do
    test "filters edges valid at specific time" do
      past_edge =
        Temporal.set_validity(
          Temporal.create_edge("A", "B", "X", "Y"),
          ~U[2024-01-01 00:00:00Z],
          ~U[2024-02-01 00:00:00Z]
        )

      current_edge = Temporal.create_edge("C", "D", "X", "Y")

      edges = [past_edge, current_edge]
      check_time = ~U[2024-03-01 00:00:00Z]
      filtered = Temporal.filter_valid_at(edges, check_time)

      assert length(filtered) == 1
      assert hd(filtered).from == "C"
    end
  end

  describe "group_by_status/1" do
    test "groups edges by status" do
      valid = Temporal.create_edge("A", "B", "X", "Y")
      invalid = Temporal.invalidate(Temporal.create_edge("C", "D", "X", "Y"))
      expired = Temporal.expire(Temporal.create_edge("E", "F", "X", "Y"))

      edges = [valid, invalid, expired]
      grouped = Temporal.group_by_status(edges)

      assert length(grouped.valid) == 1
      assert length(grouped.invalid) == 1
      assert length(grouped.expired) == 1
    end
  end

  describe "to_memgraph_props/1" do
    test "converts edge to memgraph format" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      props = Temporal.to_memgraph_props(edge)

      assert is_binary(props["created_at"])
      assert is_binary(props["valid_at"])
      assert props["invalid_at"] == nil
      assert props["expired_at"] == nil
      assert props["type"] == "KNOWS"
      assert props["fact"] == "Alice knows Bob"
    end
  end

  describe "from_memgraph_props/1" do
    test "parses memgraph properties" do
      props = %{
        "from" => "Alice",
        "to" => "Bob",
        "type" => "KNOWS",
        "fact" => "Alice knows Bob",
        "created_at" => "2024-01-15T10:00:00Z",
        "valid_at" => "2024-01-15T10:00:00Z",
        "invalid_at" => nil,
        "expired_at" => nil
      }

      edge = Temporal.from_memgraph_props(props)

      assert edge.from == "Alice"
      assert edge.to == "Bob"
      assert %DateTime{} = edge.created_at
      assert %DateTime{} = edge.valid_at
    end
  end

  describe "format/2" do
    test "formats edge without temporal info" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      formatted = Temporal.format(edge, false)

      assert formatted =~ "Alice"
      assert formatted =~ "Bob"
      assert formatted =~ "KNOWS"
      refute formatted =~ "Valid:"
    end

    test "formats edge with temporal info" do
      edge = Temporal.create_edge("Alice", "Bob", "KNOWS", "Alice knows Bob")
      formatted = Temporal.format(edge, true)

      assert formatted =~ "Alice"
      assert formatted =~ "Valid:"
      assert formatted =~ "VALID"
    end
  end
end
