defmodule Miroex.Simulation.Environment do
  @moduledoc """
  Environment GenServer that manages posts and social graph for a platform.
  """
  use GenServer
  alias Miroex.Simulation.Post
  require Logger

  defstruct [:posts, :follows, :post_counter, :simulation_id, :platform_type]

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      platform_type: Keyword.fetch!(opts, :platform),
      posts: [],
      follows: %{},
      post_counter: 0,
      simulation_id: Keyword.fetch!(opts, :simulation_id)
    }

    {:ok, state}
  end

  def create_post(env_pid, agent_id, agent_name, content) do
    GenServer.call(env_pid, {:create_post, agent_id, agent_name, content})
  end

  def like_post(env_pid, agent_id, post_id) do
    GenServer.call(env_pid, {:like_post, agent_id, post_id})
  end

  def comment_post(env_pid, agent_id, post_id, content) do
    GenServer.call(env_pid, {:comment_post, agent_id, post_id, content})
  end

  def follow_user(env_pid, follower_id, followed_id) do
    GenServer.call(env_pid, {:follow_user, follower_id, followed_id})
  end

  def retweet(env_pid, agent_id, post_id, content) do
    GenServer.call(env_pid, {:retweet, agent_id, post_id, content})
  end

  def get_timeline(env_pid, agent_id, limit \\ 20) do
    GenServer.call(env_pid, {:get_timeline, agent_id, limit})
  end

  def get_recent_posts(env_pid, limit \\ 50) do
    GenServer.call(env_pid, {:get_recent_posts, limit})
  end

  def get_post(env_pid, post_id) do
    GenServer.call(env_pid, {:get_post, post_id})
  end

  @impl true
  def handle_call({:create_post, agent_id, agent_name, content}, _from, state) do
    post_id = "#{state.platform_type}_#{state.post_counter + 1}"

    post = %Post{
      post_id: post_id,
      author_id: agent_id,
      author_name: agent_name,
      content: content,
      timestamp: DateTime.utc_now(),
      likes: [],
      comments: [],
      retweets: [],
      platform: state.platform_type
    }

    new_state = %{state | posts: [post | state.posts], post_counter: state.post_counter + 1}
    Logger.info("Post created: #{post_id} by #{agent_name}")

    {:reply, {:ok, post}, new_state}
  end

  @impl true
  def handle_call({:like_post, agent_id, post_id}, _from, state) do
    case find_post(state.posts, post_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      post ->
        if agent_id in post.likes do
          {:reply, {:ok, :already_liked}, state}
        else
          updated_post = %{post | likes: [agent_id | post.likes]}
          updated_posts = replace_post(state.posts, updated_post)
          {:reply, {:ok, updated_post}, %{state | posts: updated_posts}}
        end
    end
  end

  @impl true
  def handle_call({:comment_post, agent_id, post_id, content}, _from, state) do
    case find_post(state.posts, post_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      post ->
        comment = %{
          comment_id: "#{post_id}_comment_#{length(post.comments) + 1}",
          author_id: agent_id,
          content: content,
          timestamp: DateTime.utc_now()
        }

        updated_post = %{post | comments: [comment | post.comments]}
        updated_posts = replace_post(state.posts, updated_post)
        {:reply, {:ok, updated_post}, %{state | posts: updated_posts}}
    end
  end

  @impl true
  def handle_call({:follow_user, follower_id, followed_id}, _from, state) do
    new_follows =
      Map.update(state.follows, follower_id, [followed_id], fn list ->
        if followed_id in list, do: list, else: [followed_id | list]
      end)

    {:reply, {:ok, followed_id}, %{state | follows: new_follows}}
  end

  @impl true
  def handle_call({:retweet, agent_id, post_id, content}, _from, state) do
    case find_post(state.posts, post_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      original_post ->
        rt_content = if content, do: content, else: "RT: #{original_post.content}"
        new_post_id = "#{state.platform_type}_#{state.post_counter + 1}"

        new_post = %Post{
          post_id: new_post_id,
          author_id: agent_id,
          author_name: "user_#{agent_id}",
          content: rt_content,
          timestamp: DateTime.utc_now(),
          likes: [],
          comments: [],
          retweets: [],
          platform: state.platform_type
        }

        updated_original = %{original_post | retweets: [new_post_id | original_post.retweets]}
        updated_posts = replace_post(state.posts, updated_original)
        all_posts = [new_post | updated_posts]

        {:reply, {:ok, new_post},
         %{state | posts: all_posts, post_counter: state.post_counter + 1}}
    end
  end

  @impl true
  def handle_call({:get_timeline, agent_id, limit}, _from, state) do
    following = Map.get(state.follows, agent_id, [])

    timeline =
      state.posts
      |> Enum.filter(fn post -> post.author_id == agent_id or post.author_id in following end)
      |> Enum.take(limit)

    {:reply, timeline, state}
  end

  @impl true
  def handle_call({:get_recent_posts, limit}, _from, state) do
    recent = Enum.take(state.posts, limit)
    {:reply, recent, state}
  end

  @impl true
  def handle_call({:get_post, post_id}, _from, state) do
    post = find_post(state.posts, post_id)
    {:reply, post, state}
  end

  defp find_post(posts, post_id) do
    Enum.find(posts, fn p -> p.post_id == post_id end)
  end

  defp replace_post(posts, new_post) do
    Enum.map(posts, fn p ->
      if p.post_id == new_post.post_id, do: new_post, else: p
    end)
  end
end
