defmodule Miroex.Reports do
  @moduledoc """
  The Reports context.
  """
  import Ecto.Query, warn: false
  alias Miroex.Repo
  alias Miroex.Reports.Report

  def list_reports(user_id) do
    Repo.all(from(r in Report, where: r.user_id == ^user_id, order_by: [desc: r.inserted_at]))
  end

  def list_reports_by_simulation(simulation_id) do
    Repo.all(
      from(r in Report, where: r.simulation_id == ^simulation_id, order_by: [desc: r.inserted_at])
    )
  end

  def get_report!(id, user_id) do
    Repo.one!(from(r in Report, where: r.id == ^id and r.user_id == ^user_id))
  end

  def get_report(id) do
    Repo.get(Report, id)
  end

  def get_report_by_simulation(simulation_id) do
    Repo.one(from(r in Report, where: r.simulation_id == ^simulation_id))
  end

  def create_report(attrs, user_id) do
    attrs = Map.put(attrs, :user_id, user_id)

    %Report{}
    |> Report.changeset(attrs)
    |> Repo.insert()
  end

  def update_report(%Report{} = report, attrs) do
    report
    |> Report.changeset(attrs)
    |> Repo.update()
  end

  def delete_report(%Report{} = report) do
    Repo.delete(report)
  end

  def add_report_section(report_id, section) do
    report = get_report(report_id)

    if report do
      sections = report.sections ++ [section]
      update_report(report, %{sections: sections})
    end
  end

  def set_report_content(report_id, content) do
    report = get_report(report_id)

    if report do
      update_report(report, %{full_report: content, status: :completed, progress: 100})
    end
  end

  def update_report_progress(report_id, progress) do
    report = get_report(report_id)

    if report do
      update_report(report, %{progress: progress})
    end
  end
end
