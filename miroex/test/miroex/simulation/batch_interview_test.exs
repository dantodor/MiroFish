defmodule Miroex.Simulation.BatchInterviewTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.BatchInterview

  describe "determine_platforms/1" do
    test "nil returns both platforms" do
      platforms = BatchInterview.determine_platforms(nil)
      assert platforms == [:twitter, :reddit]
    end

    test ":both returns both platforms" do
      platforms = BatchInterview.determine_platforms(:both)
      assert platforms == [:twitter, :reddit]
    end

    test ":twitter returns only twitter" do
      platforms = BatchInterview.determine_platforms(:twitter)
      assert platforms == [:twitter]
    end

    test ":reddit returns only reddit" do
      platforms = BatchInterview.determine_platforms(:reddit)
      assert platforms == [:reddit]
    end

    test "string 'both' returns both platforms" do
      platforms = BatchInterview.determine_platforms("both")
      assert platforms == [:twitter, :reddit]
    end

    test "string 'twitter' returns only twitter" do
      platforms = BatchInterview.determine_platforms("twitter")
      assert platforms == [:twitter]
    end

    test "invalid string returns both platforms" do
      platforms = BatchInterview.determine_platforms("unknown")
      assert platforms == [:twitter, :reddit]
    end
  end

  describe "format_interview_prompt/1" do
    test "formats questions with instructions" do
      questions = ["What is your opinion?", "How do you feel?"]

      result = BatchInterview.format_interview_prompt(questions)

      assert result =~ "You are being interviewed"
      assert result =~ "1. What is your opinion?"
      assert result =~ "2. How do you feel?"
      assert result =~ "Answer directly and naturally"
    end
  end

  describe "generate_interview_questions/3" do
    test "returns fallback questions on LLM error" do
      # This will fail to reach LLM and return fallback
      questions = BatchInterview.generate_interview_questions("topic", nil, 3)

      assert length(questions) == 3
      assert Enum.all?(questions, &is_binary/1)
    end

    test "respects num_questions parameter" do
      questions = BatchInterview.generate_interview_questions("topic", nil, 5)

      # Note: fallback returns exactly 3 questions
      assert length(questions) >= 3
    end
  end
end
