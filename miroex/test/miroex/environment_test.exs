defmodule Miroex.Simulation.EnvironmentTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.Environment
  alias Miroex.Simulation.Post

  setup do
    unique_sim_id = "test_sim_#{:rand.uniform(10000)}"
    {:ok, env_pid} = Environment.start_link(platform: :twitter, simulation_id: unique_sim_id)
    %{env_pid: env_pid, simulation_id: unique_sim_id}
  end

  describe "create_post/4" do
    test "creates a new post", %{env_pid: env_pid} do
      {:ok, post} = Environment.create_post(env_pid, 1, "User1", "Hello world!")

      assert post.content == "Hello world!"
      assert post.author_id == 1
      assert post.author_name == "User1"
      assert post.platform == :twitter
      assert post.likes == []
      assert post.comments == []
    end

    test "increments post counter", %{env_pid: env_pid} do
      {:ok, post1} = Environment.create_post(env_pid, 1, "User1", "Post 1")
      {:ok, post2} = Environment.create_post(env_pid, 2, "User2", "Post 2")

      assert post1.post_id == "twitter_1"
      assert post2.post_id == "twitter_2"
    end
  end

  describe "like_post/3" do
    test "likes a post", %{env_pid: env_pid} do
      {:ok, post} = Environment.create_post(env_pid, 1, "User1", "Test post")
      {:ok, updated_post} = Environment.like_post(env_pid, 2, post.post_id)

      assert 2 in updated_post.likes
    end

    test "returns error for non-existent post", %{env_pid: env_pid} do
      result = Environment.like_post(env_pid, 1, "nonexistent")
      assert result == {:error, :not_found}
    end

    test "returns already_liked if user already liked", %{env_pid: env_pid} do
      {:ok, post} = Environment.create_post(env_pid, 1, "User1", "Test post")
      {:ok, _} = Environment.like_post(env_pid, 2, post.post_id)
      result = Environment.like_post(env_pid, 2, post.post_id)

      assert result == {:ok, :already_liked}
    end
  end

  describe "comment_post/4" do
    test "adds a comment to a post", %{env_pid: env_pid} do
      {:ok, post} = Environment.create_post(env_pid, 1, "User1", "Test post")
      {:ok, updated_post} = Environment.comment_post(env_pid, 2, post.post_id, "Great post!")

      assert length(updated_post.comments) == 1
      assert hd(updated_post.comments).content == "Great post!"
      assert hd(updated_post.comments).author_id == 2
    end

    test "returns error for non-existent post", %{env_pid: env_pid} do
      result = Environment.comment_post(env_pid, 1, "nonexistent", "Comment")
      assert result == {:error, :not_found}
    end
  end

  describe "follow_user/3" do
    test "makes user1 follow user2", %{env_pid: env_pid} do
      {:ok, followed_id} = Environment.follow_user(env_pid, 1, 2)
      assert followed_id == 2
    end

    test "user can follow multiple users", %{env_pid: env_pid} do
      {:ok, _} = Environment.follow_user(env_pid, 1, 2)
      {:ok, _} = Environment.follow_user(env_pid, 1, 3)
      {:ok, followed_id} = Environment.follow_user(env_pid, 1, 4)

      assert followed_id == 4
    end

    test "prevent duplicate follows", %{env_pid: env_pid} do
      {:ok, _} = Environment.follow_user(env_pid, 1, 2)
      {:ok, _} = Environment.follow_user(env_pid, 1, 2)
      result = Environment.follow_user(env_pid, 1, 2)

      assert result == {:ok, 2}
    end
  end

  describe "get_timeline/3" do
    test "returns posts from followed users", %{env_pid: env_pid} do
      {:ok, _} = Environment.create_post(env_pid, 1, "User1", "Post from User1")
      {:ok, _} = Environment.create_post(env_pid, 2, "User2", "Post from User2")

      {:ok, _} = Environment.follow_user(env_pid, 3, 1)

      timeline = Environment.get_timeline(env_pid, 3, 10)
      assert length(timeline) >= 1
      assert Enum.any?(timeline, fn p -> p.author_id == 1 end)
    end

    test "includes own posts in timeline", %{env_pid: env_pid} do
      {:ok, _} = Environment.create_post(env_pid, 1, "User1", "My post")

      timeline = Environment.get_timeline(env_pid, 1, 10)
      assert length(timeline) >= 1
    end
  end

  describe "get_recent_posts/2" do
    test "returns recent posts up to limit", %{env_pid: env_pid} do
      for i <- 1..10, do: Environment.create_post(env_pid, 1, "User", "Post #{i}")

      recent = Environment.get_recent_posts(env_pid, 5)
      assert length(recent) == 5
    end
  end

  describe "get_post/2" do
    test "returns a specific post", %{env_pid: env_pid} do
      {:ok, created} = Environment.create_post(env_pid, 1, "User", "Test")
      post = Environment.get_post(env_pid, created.post_id)

      assert post.post_id == created.post_id
      assert post.content == "Test"
    end

    test "returns nil for non-existent post", %{env_pid: env_pid} do
      post = Environment.get_post(env_pid, "nonexistent")
      assert post == nil
    end
  end
end
