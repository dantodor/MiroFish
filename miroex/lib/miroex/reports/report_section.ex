defmodule Miroex.Reports.ReportSection do
  @moduledoc """
  Represents a section within a report.

  Each section has:
  - title: The section title
  - content: The generated content (markdown)
  - index: Position in the report (0-based)
  - status: Current generation status
  """

  @enforce_keys [:title, :index]
  defstruct [
    :title,
    :description,
    :content,
    :index,
    :status
  ]

  @type t :: %__MODULE__{
          title: String.t(),
          description: String.t() | nil,
          content: String.t(),
          index: non_neg_integer(),
          status: Status.t()
        }

  @type status :: :pending | :generating | :completed | :failed

  @doc """
  Create a new pending section.
  """
  @spec new(String.t(), non_neg_integer(), String.t() | nil) :: t()
  def new(title, index, description \\ nil) do
    %__MODULE__{
      title: title,
      description: description,
      content: "",
      index: index,
      status: :pending
    }
  end

  @doc """
  Mark section as generating.
  """
  @spec generating(t()) :: t()
  def generating(section) do
    %{section | status: :generating}
  end

  @doc """
  Mark section as completed with content.
  """
  @spec completed(t(), String.t()) :: t()
  def completed(section, content) do
    %{section | status: :completed, content: content}
  end

  @doc """
  Mark section as failed.
  """
  @spec failed(t()) :: t()
  def failed(section) do
    %{section | status: :failed}
  end

  @doc """
  Convert section to markdown string.
  """
  @spec to_markdown(t(), integer()) :: String.t()
  def to_markdown(section, heading_level \\ 2) do
    prefix = String.duplicate("#", heading_level)
    "#{prefix} #{section.title}\n\n#{section.content}\n"
  end
end
