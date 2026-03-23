defmodule Miroex.Simulation.Post do
  @moduledoc """
  Represents a social media post.
  """
  defstruct [
    :post_id,
    :author_id,
    :author_name,
    :content,
    :timestamp,
    :likes,
    :comments,
    :retweets,
    :platform
  ]

  @type t :: %__MODULE__{
          post_id: String.t(),
          author_id: integer(),
          author_name: String.t(),
          content: String.t(),
          timestamp: DateTime.t(),
          likes: [integer()],
          comments: [map()],
          retweets: [integer()],
          platform: :twitter | :reddit
        }
end
