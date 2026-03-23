defmodule Miroex.ActionTypesTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.ActionTypes

  describe "action structs" do
    test "CreatePost struct" do
      post = %ActionTypes.CreatePost{content: "Hello world"}
      assert post.content == "Hello world"
    end

    test "LikePost struct" do
      like = %ActionTypes.LikePost{post_id: "post_123"}
      assert like.post_id == "post_123"
    end

    test "CommentPost struct" do
      comment = %ActionTypes.CommentPost{post_id: "post_123", content: "Great post!"}
      assert comment.post_id == "post_123"
      assert comment.content == "Great post!"
    end

    test "FollowUser struct" do
      follow = %ActionTypes.FollowUser{user_id: 42}
      assert follow.user_id == 42
    end

    test "RetweetPost struct" do
      rt = %ActionTypes.RetweetPost{post_id: "post_123", content: "RT: Great!"}
      assert rt.post_id == "post_123"
      assert rt.content == "RT: Great!"
    end

    test "ReplyPost struct" do
      reply = %ActionTypes.ReplyPost{post_id: "post_123", content: "Reply here"}
      assert reply.post_id == "post_123"
      assert reply.content == "Reply here"
    end
  end

  describe "action_types/0" do
    test "returns all action types" do
      types = ActionTypes.action_types()
      assert :create_post in types
      assert :like_post in types
      assert :comment_post in types
      assert :follow_user in types
      assert :retweet_post in types
      assert :reply_post in types
    end
  end

  describe "twitter_actions/0" do
    test "returns twitter-specific actions" do
      actions = ActionTypes.twitter_actions()
      assert :create_post in actions
      assert :like_post in actions
      assert :comment_post in actions
      assert :follow_user in actions
      assert :retweet_post in actions
      assert :reply_post in actions
    end
  end

  describe "reddit_actions/0" do
    test "returns reddit-specific actions (no retweet)" do
      actions = ActionTypes.reddit_actions()
      assert :create_post in actions
      assert :like_post in actions
      assert :comment_post in actions
      assert :follow_user in actions
      refute :retweet_post in actions
      refute :reply_post in actions
    end
  end
end
