defmodule Miroex.Simulation.Serializers.EnvironmentStateTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.Serializers.EnvironmentState
  alias Miroex.Simulation.Post

  describe "serialize/1" do
    test "serializes environment state to map" do
      post1 = %Post{
        post_id: "twitter_1",
        author_id: 42,
        author_name: "TestUser",
        content: "Hello world",
        timestamp: DateTime.utc_now(),
        likes: [1, 2],
        comments: [
          %{comment_id: "c1", author_id: 3, content: "Nice!", timestamp: DateTime.utc_now()}
        ],
        retweets: [1],
        platform: :twitter
      }

      env_state = %{
        platform_type: :twitter,
        simulation_id: "sim_123",
        posts: [post1],
        likes: %{1 => [42], 2 => [1]},
        follows: %{1 => [2, 3], 2 => [1]},
        retweets: %{1 => [42]},
        post_counter: 5
      }

      result = EnvironmentState.serialize(env_state)

      assert result.platform == "twitter"
      assert result.simulation_id == "sim_123"
      assert is_list(result.posts)
      assert length(result.posts) == 1
      assert result.posts |> hd() |> Map.get(:post_id) == "twitter_1"
      assert result.likes == [{1, [42]}, {2, [1]}]
      assert result.follows == [{1, [2, 3]}, {2, [1]}]
      assert result.retweets == [{1, [42]}]
      assert result.next_post_id == 5
    end

    test "handles nil values" do
      env_state = %{
        platform_type: :reddit,
        simulation_id: "sim_1",
        posts: nil,
        likes: nil,
        follows: nil,
        retweets: nil,
        post_counter: nil
      }

      result = EnvironmentState.serialize(env_state)

      assert result.posts == []
      assert result.likes == []
      assert result.follows == []
      assert result.retweets == []
      assert result.next_post_id == 1
    end
  end

  describe "deserialize/1" do
    test "deserializes map back to environment state" do
      data = %{
        platform: "twitter",
        simulation_id: "sim_123",
        posts: [
          %{
            post_id: "twitter_1",
            author_id: 42,
            author_name: "TestUser",
            content: "Hello world",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            likes: [1, 2],
            comments: [],
            retweets: [],
            platform: "twitter"
          }
        ],
        likes: [{1, [42]}, {2, [1]}],
        follows: [{1, [2, 3]}],
        retweets: [{1, [42]}],
        next_post_id: 5
      }

      result = EnvironmentState.deserialize(data)

      assert result.platform_type == :twitter
      assert result.simulation_id == "sim_123"
      assert is_list(result.posts)
      assert length(result.posts) == 1
      assert (result.posts |> hd()).post_id == "twitter_1"
      assert result.likes == %{1 => [42], 2 => [1]}
      assert result.follows == %{1 => [2, 3]}
      assert result.retweets == %{1 => [42]}
      assert result.post_counter == 5
    end

    test "handles empty lists" do
      data = %{
        platform: "reddit",
        simulation_id: "sim_1",
        posts: [],
        likes: [],
        follows: [],
        retweets: [],
        next_post_id: nil
      }

      result = EnvironmentState.deserialize(data)

      assert result.platform_type == :reddit
      assert result.posts == []
      assert result.likes == %{}
      assert result.follows == %{}
      assert result.retweets == %{}
      assert result.post_counter == 1
    end
  end
end
