defmodule Miroex.Simulation.PostTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.Post

  test "creates a post struct" do
    post = %Post{
      post_id: "twitter_1",
      author_id: 42,
      author_name: "TestUser",
      content: "Hello world!",
      timestamp: DateTime.utc_now(),
      likes: [],
      comments: [],
      retweets: [],
      platform: :twitter
    }

    assert post.post_id == "twitter_1"
    assert post.author_id == 42
    assert post.author_name == "TestUser"
    assert post.content == "Hello world!"
    assert post.likes == []
    assert post.comments == []
    assert post.retweets == []
    assert post.platform == :twitter
  end

  test "post with likes and comments" do
    post = %Post{
      post_id: "twitter_2",
      author_id: 1,
      author_name: "User1",
      content: "Test post",
      timestamp: DateTime.utc_now(),
      likes: [2, 3, 4],
      comments: [
        %{comment_id: "c1", author_id: 5, content: "Nice!", timestamp: DateTime.utc_now()}
      ],
      retweets: [],
      platform: :twitter
    }

    assert length(post.likes) == 3
    assert length(post.comments) == 1
    assert hd(post.comments).content == "Nice!"
  end

  test "reddit platform post" do
    post = %Post{
      post_id: "reddit_1",
      author_id: 100,
      author_name: "RedditUser",
      content: "Posted on reddit",
      timestamp: DateTime.utc_now(),
      likes: [],
      comments: [],
      retweets: [],
      platform: :reddit
    }

    assert post.platform == :reddit
    assert post.post_id == "reddit_1"
  end
end
