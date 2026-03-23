defmodule Miroex.Simulation.ActionTypes do
  @moduledoc """
  Defines action types for OASIS simulation.
  """

  defmodule CreatePost do
    @enforce_keys [:content]
    defstruct [:content]
  end

  defmodule LikePost do
    @enforce_keys [:post_id]
    defstruct [:post_id]
  end

  defmodule CommentPost do
    @enforce_keys [:post_id, :content]
    defstruct [:post_id, :content]
  end

  defmodule FollowUser do
    @enforce_keys [:user_id]
    defstruct [:user_id]
  end

  defmodule RetweetPost do
    @enforce_keys [:post_id, :content]
    defstruct [:post_id, :content]
  end

  defmodule ReplyPost do
    @enforce_keys [:post_id, :content]
    defstruct [:post_id, :content]
  end

  @type t ::
          CreatePost.t()
          | LikePost.t()
          | CommentPost.t()
          | FollowUser.t()
          | RetweetPost.t()
          | ReplyPost.t()

  @action_types [
    :create_post,
    :like_post,
    :comment_post,
    :follow_user,
    :retweet_post,
    :reply_post
  ]

  def action_types, do: @action_types

  def twitter_actions,
    do: [:create_post, :like_post, :comment_post, :follow_user, :retweet_post, :reply_post]

  def reddit_actions, do: [:create_post, :like_post, :comment_post, :follow_user]

  defstruct [:create_post, :like_post, :comment_post, :follow_user, :retweet_post, :reply_post]
end
