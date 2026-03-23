defmodule Miroex.Reports.ReportSectionTest do
  use ExUnit.Case, async: true

  alias Miroex.Reports.ReportSection

  describe "new/3" do
    test "creates a pending section" do
      section = ReportSection.new("Test Section", 0, "Description")
      assert section.title == "Test Section"
      assert section.index == 0
      assert section.description == "Description"
      assert section.content == ""
      assert section.status == :pending
    end

    test "creates section without description" do
      section = ReportSection.new("Test Section", 0)
      assert section.description == nil
    end
  end

  describe "generating/1" do
    test "marks section as generating" do
      section = ReportSection.new("Test", 0)
      updated = ReportSection.generating(section)
      assert updated.status == :generating
    end
  end

  describe "completed/2" do
    test "marks section as completed with content" do
      section = ReportSection.new("Test", 0)
      updated = ReportSection.completed(section, "Generated content here")
      assert updated.status == :completed
      assert updated.content == "Generated content here"
    end
  end

  describe "failed/1" do
    test "marks section as failed" do
      section = ReportSection.new("Test", 0)
      updated = ReportSection.failed(section)
      assert updated.status == :failed
    end
  end

  describe "to_markdown/2" do
    test "converts section to markdown with default heading level" do
      section =
        ReportSection.new("My Title", 0)
        |> ReportSection.completed("Some content here")

      md = ReportSection.to_markdown(section)
      assert md == "## My Title\n\nSome content here\n"
    end

    test "converts section to markdown with custom heading level" do
      section =
        ReportSection.new("My Title", 0)
        |> ReportSection.completed("Some content here")

      md = ReportSection.to_markdown(section, 3)
      assert md == "### My Title\n\nSome content here\n"
    end
  end
end
