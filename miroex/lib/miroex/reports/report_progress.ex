defmodule Miroex.Reports.ReportProgress do
  @moduledoc """
  GenServer to track report generation progress.

  Provides real-time progress updates for the report generation process:
  - Planning phase
  - Section generation
  - Overall completion

  Used by the LiveView UI to show progress to users.
  """
  use GenServer
  require Logger

  @enforce_keys [:report_id]
  defstruct [
    :report_id,
    :status,
    :current_section,
    :current_section_index,
    :overall_percent,
    :sections_completed,
    :total_sections,
    :started_at,
    :completed_at,
    :error
  ]

  @type t :: %__MODULE__{
          report_id: String.t(),
          status: Status.t(),
          current_section: String.t() | nil,
          current_section_index: non_neg_integer(),
          overall_percent: 0..100,
          sections_completed: non_neg_integer(),
          total_sections: non_neg_integer(),
          started_at: DateTime.t(),
          completed_at: DateTime.t() | nil,
          error: String.t() | nil
        }

  @type status :: :idle | :planning | :generating | :section_complete | :completed | :failed

  @default_section_percent 20
  @planning_percent 10

  # Client API

  @doc """
  Start a new progress tracker for a report.
  """
  @spec start_link(String.t()) :: {:ok, pid()} | {:error, term()}
  def start_link(report_id) do
    name = via_tuple(report_id)
    GenServer.start_link(__MODULE__, %{report_id: report_id}, name: name)
  end

  @doc """
  Get progress via report_id.
  """
  @spec get_progress(String.t()) :: {:ok, t()} | {:error, term()}
  def get_progress(report_id) do
    name = via_tuple(report_id)
    GenServer.call(name, :get_progress)
  end

  @doc """
  Update progress with new status.
  """
  @spec update(String.t(), status(), String.t(), integer()) :: :ok
  def update(report_id, status, current_section \\ "", percent \\ 0) do
    name = via_tuple(report_id)
    GenServer.cast(name, {:update, status, current_section, percent})
  end

  @doc """
  Mark planning as started.
  """
  @spec planning_started(String.t()) :: :ok
  def planning_started(report_id) do
    name = via_tuple(report_id)
    GenServer.cast(name, {:planning_started})
  end

  @doc """
  Mark planning as complete.
  """
  @spec planning_complete(String.t(), non_neg_integer()) :: :ok
  def planning_complete(report_id, total_sections) do
    name = via_tuple(report_id)
    GenServer.cast(name, {:planning_complete, total_sections})
  end

  @doc """
  Mark a section as started.
  """
  @spec section_started(String.t(), String.t(), non_neg_integer()) :: :ok
  def section_started(report_id, section_title, section_index) do
    name = via_tuple(report_id)
    GenServer.cast(name, {:section_started, section_title, section_index})
  end

  @doc """
  Mark a section as complete and update progress.
  """
  @spec section_complete(String.t(), String.t(), non_neg_integer()) :: :ok
  def section_complete(report_id, section_title, section_index) do
    name = via_tuple(report_id)
    GenServer.cast(name, {:section_complete, section_title, section_index})
  end

  @doc """
  Mark report as complete.
  """
  @spec complete(String.t()) :: :ok
  def complete(report_id) do
    name = via_tuple(report_id)
    GenServer.cast(name, :complete)
  end

  @doc """
  Mark report as failed.
  """
  @spec fail(String.t(), String.t()) :: :ok
  def fail(report_id, error_message) do
    name = via_tuple(report_id)
    GenServer.cast(name, {:fail, error_message})
  end

  @doc """
  Stop and cleanup progress tracker.
  """
  @spec stop(String.t()) :: :ok
  def stop(report_id) do
    name = via_tuple(report_id)
    GenServer.stop(name)
  end

  # Server Callbacks

  @impl true
  def init(%{report_id: report_id}) do
    state = %__MODULE__{
      report_id: report_id,
      status: :idle,
      current_section: nil,
      current_section_index: 0,
      overall_percent: 0,
      sections_completed: 0,
      total_sections: 0,
      started_at: DateTime.utc_now(),
      completed_at: nil,
      error: nil
    }

    Logger.info("ReportProgress started for #{report_id}")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_progress, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_cast({:update, status, section, percent}, state) do
    new_state = %{state | status: status, current_section: section, overall_percent: percent}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:planning_started}, state) do
    Logger.info("Report #{state.report_id}: Planning started")
    new_state = %{state | status: :planning, overall_percent: 0}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:planning_complete, total_sections}, state) do
    Logger.info("Report #{state.report_id}: Planning complete, #{total_sections} sections")

    new_state = %{
      state
      | status: :generating,
        total_sections: total_sections,
        overall_percent: @planning_percent
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:section_started, section_title, section_index}, state) do
    Logger.info("Report #{state.report_id}: Section #{section_index} started - #{section_title}")

    new_state = %{
      state
      | status: :generating,
        current_section: section_title,
        current_section_index: section_index
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:section_complete, section_title, section_index}, state) do
    completed = state.sections_completed + 1

    section_percent = @default_section_percent * completed + @planning_percent
    section_percent = min(section_percent, 95)

    Logger.info(
      "Report #{state.report_id}: Section #{section_index} complete (#{completed}/#{state.total_sections})"
    )

    new_state = %{
      state
      | status: :section_complete,
        sections_completed: completed,
        overall_percent: section_percent
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:complete, state) do
    Logger.info("Report #{state.report_id}: Complete!")

    new_state = %{
      state
      | status: :completed,
        overall_percent: 100,
        completed_at: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:fail, error_message}, state) do
    Logger.error("Report #{state.report_id}: Failed - #{error_message}")
    new_state = %{state | status: :failed, error: error_message, completed_at: DateTime.utc_now()}
    {:noreply, new_state}
  end

  # Helper

  defp via_tuple(report_id) do
    {:via, Registry, {Registry.ReportProgress, report_id}}
  end
end
