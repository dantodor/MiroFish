defmodule Miroex.Graph.FactCreatorTest do
  use ExUnit.Case, async: true

  alias Miroex.Graph.FactCreator

  describe "create_facts_from_action/3" do
    test "creates fact from create_post action" do
      graph_id = "test_graph"

      action = %{
        action_type: :create_post,
        agent_id: 1,
        content: "This is a test post",
        round: 5,
        timestamp: DateTime.utc_now()
      }

      agent_info = %{name: "Alice"}

      result = FactCreator.create_facts_from_action(graph_id, action, agent_info)

      assert {:ok, facts} = result
      assert length(facts) == 1
      fact = hd(facts)
      assert fact.from == "Alice"
      assert fact.type == "POSTED"
      assert fact.action_type == :create_post
      assert fact.round == 5
    end

    test "creates fact from like_post action" do
      graph_id = "test_graph"

      action = %{
        action_type: :like_post,
        agent_id: 1,
        target_id: 2,
        target_name: "Bob",
        round: 3,
        timestamp: DateTime.utc_now()
      }

      agent_info = %{name: "Alice"}

      result = FactCreator.create_facts_from_action(graph_id, action, agent_info)

      assert {:ok, facts} = result
      fact = hd(facts)
      assert fact.from == "Alice"
      assert fact.to == "Bob"
      assert fact.type == "LIKED"
    end

    test "creates fact from follow_user action" do
      graph_id = "test_graph"

      action = %{
        action_type: :follow_user,
        agent_id: 1,
        target_id: 2,
        target_name: "Charlie",
        round: 1,
        timestamp: DateTime.utc_now()
      }

      agent_info = %{name: "Alice"}

      result = FactCreator.create_facts_from_action(graph_id, action, agent_info)

      assert {:ok, facts} = result
      fact = hd(facts)
      assert fact.type == "FOLLOWS"
    end
  end

  describe "create_facts_from_actions/3" do
    test "creates facts from multiple actions" do
      graph_id = "test_graph"

      actions = [
        %{
          action_type: :create_post,
          agent_id: 1,
          content: "Post 1",
          round: 1,
          timestamp: DateTime.utc_now()
        },
        %{
          action_type: :create_post,
          agent_id: 2,
          content: "Post 2",
          round: 2,
          timestamp: DateTime.utc_now()
        }
      ]

      agent_info_map = %{
        1 => %{name: "Alice"},
        2 => %{name: "Bob"}
      }

      result = FactCreator.create_facts_from_actions(graph_id, actions, agent_info_map)

      assert {:ok, facts} = result
      assert length(facts) == 2
    end
  end

  describe "determine_target/2" do
    test "returns target_name when available" do
      action = %{target_name: "Bob", target_id: 2}
      agent_name = "Alice"

      # Test via create_facts_from_action
      assert {:ok, facts} =
               FactCreator.create_facts_from_action("graph", action, %{name: agent_name})

      fact = hd(facts)
      assert fact.to == "Bob"
    end

    test "returns agent name for self-actions" do
      action = %{action_type: :create_post, agent_id: 1, content: "Hello"}
      agent_name = "Alice"

      assert {:ok, facts} =
               FactCreator.create_facts_from_action("graph", action, %{name: agent_name})

      fact = hd(facts)
      assert fact.to == "Alice"
    end
  end

  describe "build_fact_text/4" do
    test "builds text for create_post" do
      action = %{content: "Hello world, this is a long post that should be truncated"}
      text = FactCreator.build_fact_text(:create_post, "Alice", "Alice", action)

      assert text =~ "Alice"
      assert text =~ "created a post"
      assert String.length(text) < 100
    end

    test "builds text for comment_post" do
      action = %{content: "Nice post!"}
      text = FactCreator.build_fact_text(:comment_post, "Alice", "Bob", action)

      assert text =~ "Alice"
      assert text =~ "commented on"
      assert text =~ "Bob"
    end

    test "builds text for follow_user" do
      text = FactCreator.build_fact_text(:follow_user, "Alice", "Bob", %{})

      assert text =~ "Alice"
      assert text =~ "followed"
      assert text =~ "Bob"
    end

    test "builds text for retweet_post" do
      action = %{content: "RT: Original content here"}
      text = FactCreator.build_fact_text(:retweet_post, "Alice", "Bob", action)

      assert text =~ "retweeted"
      assert text =~ "Bob"
    end
  end

  describe "action to edge type mapping" do
    test "maps create_post to POSTED" do
      action = %{
        action_type: :create_post,
        agent_id: 1,
        content: "Test",
        round: 1,
        timestamp: DateTime.utc_now()
      }

      {:ok, facts} = FactCreator.create_facts_from_action("graph", action, %{name: "Alice"})
      assert hd(facts).type == "POSTED"
    end

    test "maps like_post to LIKED" do
      action = %{
        action_type: :like_post,
        agent_id: 1,
        target_id: 2,
        round: 1,
        timestamp: DateTime.utc_now()
      }

      {:ok, facts} = FactCreator.create_facts_from_action("graph", action, %{name: "Alice"})
      assert hd(facts).type == "LIKED"
    end

    test "maps comment_post to COMMENTED_ON" do
      action = %{
        action_type: :comment_post,
        agent_id: 1,
        target_id: 2,
        content: "Comment",
        round: 1,
        timestamp: DateTime.utc_now()
      }

      {:ok, facts} = FactCreator.create_facts_from_action("graph", action, %{name: "Alice"})
      assert hd(facts).type == "COMMENTED_ON"
    end

    test "maps follow_user to FOLLOWS" do
      action = %{
        action_type: :follow_user,
        agent_id: 1,
        target_id: 2,
        round: 1,
        timestamp: DateTime.utc_now()
      }

      {:ok, facts} = FactCreator.create_facts_from_action("graph", action, %{name: "Alice"})
      assert hd(facts).type == "FOLLOWS"
    end

    test "maps retweet_post to RETWEETED" do
      action = %{
        action_type: :retweet_post,
        agent_id: 1,
        target_id: 2,
        content: "RT",
        round: 1,
        timestamp: DateTime.utc_now()
      }

      {:ok, facts} = FactCreator.create_facts_from_action("graph", action, %{name: "Alice"})
      assert hd(facts).type == "RETWEETED"
    end

    test "maps reply_post to REPLIED_TO" do
      action = %{
        action_type: :reply_post,
        agent_id: 1,
        target_id: 2,
        content: "Reply",
        round: 1,
        timestamp: DateTime.utc_now()
      }

      {:ok, facts} = FactCreator.create_facts_from_action("graph", action, %{name: "Alice"})
      assert hd(facts).type == "REPLIED_TO"
    end

    test "maps mention to MENTIONED" do
      action = %{
        action_type: :mention,
        agent_id: 1,
        target_id: 2,
        round: 1,
        timestamp: DateTime.utc_now()
      }

      {:ok, facts} = FactCreator.create_facts_from_action("graph", action, %{name: "Alice"})
      assert hd(facts).type == "MENTIONED"
    end
  end
end
