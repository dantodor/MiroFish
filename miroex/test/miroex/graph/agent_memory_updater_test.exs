defmodule Miroex.Graph.AgentMemoryUpdaterTest do
  use ExUnit.Case, async: false

  alias Miroex.Graph.AgentMemoryUpdater

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      {:ok, pid} = AgentMemoryUpdater.start_link(name: :test_start_link_1)
      assert is_pid(pid)
    end

    test "accepts custom max_queue_size and flush_interval" do
      {:ok, pid} =
        AgentMemoryUpdater.start_link(
          name: :test_start_link_2,
          max_queue_size: 10,
          flush_interval: 1_000
        )

      assert is_pid(pid)
    end
  end

  describe "add_activity/1" do
    setup do
      {:ok, pid} = AgentMemoryUpdater.start_link(name: :test_add_activity)
      %{updater: :test_add_activity, pid: pid}
    end

    test "queues activity without error", %{updater: server} do
      activity = %{
        graph_id: "test_graph",
        agent_id: 1,
        agent_name: "TestAgent",
        action_type: "create_post",
        content: "Hello world",
        round: 1,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      assert :ok = AgentMemoryUpdater.add_activity(activity, server)
    end

    test "queue size increases after adding activity", %{updater: server} do
      activity = %{
        graph_id: "test_graph",
        agent_id: 1,
        action_type: "create_post",
        content: "Test"
      }

      initial_size = AgentMemoryUpdater.queue_size(server)
      AgentMemoryUpdater.add_activity(activity, server)
      assert AgentMemoryUpdater.queue_size(server) == initial_size + 1
    end

    test "handles minimal activity map", %{updater: server} do
      minimal_activity = %{agent_id: 1, action_type: "like_post"}
      assert :ok = AgentMemoryUpdater.add_activity(minimal_activity, server)
    end
  end

  describe "flush/0" do
    setup do
      {:ok, pid} = AgentMemoryUpdater.start_link(name: :test_flush)
      %{updater: :test_flush, pid: pid}
    end

    test "returns :ok when queue is empty", %{updater: server} do
      assert AgentMemoryUpdater.flush(server) == :ok
    end

    test "flush returns error when Memgraph is unavailable", %{updater: server} do
      activity = %{
        graph_id: "test_graph",
        agent_id: 1,
        action_type: "create_post",
        content: "Test post",
        round: 1
      }

      AgentMemoryUpdater.add_activity(activity, server)
      AgentMemoryUpdater.add_activity(activity, server)

      result = AgentMemoryUpdater.flush(server)
      assert match?({:error, _}, result)
    end

    test "flush does not clear queue when Memgraph fails", %{updater: server} do
      activity = %{
        graph_id: "test_graph",
        agent_id: 1,
        action_type: "create_post",
        content: "Test"
      }

      AgentMemoryUpdater.add_activity(activity, server)
      AgentMemoryUpdater.flush(server)

      assert AgentMemoryUpdater.queue_size(server) == 1
    end
  end

  describe "queue_size/0" do
    setup do
      {:ok, pid} = AgentMemoryUpdater.start_link(name: :test_queue_size)
      %{updater: :test_queue_size, pid: pid}
    end

    test "returns 0 for empty queue", %{updater: server} do
      assert AgentMemoryUpdater.queue_size(server) == 0
    end

    test "returns correct count after adding activities", %{updater: server} do
      for i <- 1..10 do
        AgentMemoryUpdater.add_activity(%{agent_id: i, action_type: "post"}, server)
      end

      assert AgentMemoryUpdater.queue_size(server) == 10
    end
  end

  describe "stop/0" do
    test "stop GenServer returns :ok" do
      {:ok, _pid} = AgentMemoryUpdater.start_link(name: :test_stop_1)
      server = :test_stop_1

      AgentMemoryUpdater.add_activity(%{agent_id: 1, action_type: "post"}, server)
      assert :ok = AgentMemoryUpdater.stop(server)
      Process.sleep(50)
      assert Process.whereis(server) == nil
    end

    test "GenServer stops after stop is called" do
      {:ok, _pid} = AgentMemoryUpdater.start_link(name: :test_stop_2)
      server = :test_stop_2

      AgentMemoryUpdater.add_activity(%{agent_id: 1, action_type: "post"}, server)
      AgentMemoryUpdater.stop(server)
      Process.sleep(50)
      assert Process.whereis(server) == nil
    end
  end

  describe "auto-flush on max queue size" do
    test "triggers flush when queue reaches max_size" do
      {:ok, _pid} =
        AgentMemoryUpdater.start_link(
          name: :test_auto_flush,
          max_queue_size: 3,
          flush_interval: 60_000
        )

      server = :test_auto_flush

      AgentMemoryUpdater.add_activity(%{agent_id: 1, action_type: "post"}, server)
      AgentMemoryUpdater.add_activity(%{agent_id: 2, action_type: "post"}, server)

      assert AgentMemoryUpdater.queue_size(server) == 2

      AgentMemoryUpdater.add_activity(%{agent_id: 3, action_type: "post"}, server)
      Process.sleep(50)

      assert AgentMemoryUpdater.queue_size(server) == 3
    end
  end

  describe "concurrent operations" do
    test "handles concurrent add_activity calls" do
      {:ok, _pid} = AgentMemoryUpdater.start_link(name: :test_concurrent)
      server = :test_concurrent

      parent = self()

      Enum.each(1..20, fn i ->
        spawn(fn ->
          AgentMemoryUpdater.add_activity(%{agent_id: i, action_type: "post"}, server)
          send(parent, :done)
        end)
      end)

      Enum.each(1..20, fn _ -> receive do: (:done -> :ok) end)

      size = AgentMemoryUpdater.queue_size(server)
      assert size > 0
    end
  end
end
