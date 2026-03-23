defmodule Miroex.Simulation.Serializers.EnvironmentState do
  @moduledoc """
  Serializes Environment state for persistence.
  """
  alias Miroex.Simulation.Post

  @doc """
  Serialize an environment state map to a JSON-friendly map.
  """
  @spec serialize(map()) :: map()
  def serialize(env_state) when is_map(env_state) do
    %{
      platform: Atom.to_string(env_state.platform_type),
      simulation_id: env_state.simulation_id,
      posts: serialize_posts(env_state.posts || []),
      likes: Map.to_list(env_state.likes || %{}),
      follows: Map.to_list(env_state.follows || %{}),
      retweets: Map.to_list(env_state.retweets || %{}),
      next_post_id: env_state.post_counter || 1
    }
  end

  @doc """
  Deserialize a map back to an environment state.
  """
  @spec deserialize(map()) :: map()
  def deserialize(data) when is_map(data) do
    %{
      platform_type: String.to_existing_atom(data.platform),
      simulation_id: data.simulation_id,
      posts: deserialize_posts(data.posts || []),
      likes: Map.new(data.likes || []),
      follows: Map.new(data.follows || []),
      retweets: Map.new(data.retweets || []),
      post_counter: data.next_post_id || 1
    }
  end

  defp serialize_posts(posts) when is_list(posts) do
    Enum.map(posts, fn %Post{} = post ->
      %{
        post_id: post.post_id,
        author_id: post.author_id,
        author_name: post.author_name,
        content: post.content,
        timestamp: post.timestamp,
        likes: post.likes || [],
        comments: post.comments || [],
        retweets: post.retweets || [],
        platform: Atom.to_string(post.platform)
      }
    end)
  end

  defp deserialize_posts(data) when is_list(data) do
    Enum.map(data, fn post_data ->
      %Post{
        post_id: post_data.post_id,
        author_id: post_data.author_id,
        author_name: post_data.author_name,
        content: post_data.content,
        timestamp: post_data.timestamp,
        likes: post_data.likes || [],
        comments: post_data.comments || [],
        retweets: post_data.retweets || [],
        platform: String.to_existing_atom(post_data.platform)
      }
    end)
  end
end
