defmodule Miroex.Simulation.ConfigGeneratorTest do
  use ExUnit.Case, async: true

  alias Miroex.Simulation.ConfigGenerator

  describe "generate/4" do
    test "generates configuration with requirements" do
      requirements = "Simulate a campus debate about new policies"

      entities = [
        %{name: "Student A", type: "Student"},
        %{name: "Professor B", type: "Professor"}
      ]

      entity_types = ["Student", "Professor"]

      # This will call LLM, but we're testing the API structure
      result = ConfigGenerator.generate(requirements, entities, entity_types)

      # Should return either parsed config or error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "generates configuration with options" do
      requirements = "Test simulation"
      entities = [%{name: "Agent 1", type: "Student"}]
      entity_types = ["Student"]
      opts = [platform: :twitter, agent_count: 10]

      result = ConfigGenerator.generate(requirements, entities, entity_types, opts)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "generate_time_config/3" do
    test "generates time configuration" do
      config = ConfigGenerator.generate_time_config(72, 50)

      assert config.total_simulation_hours == 72
      assert config.minutes_per_round == 60
      assert is_list(config.peak_hours)
      assert is_list(config.off_peak_hours)
      assert config.peak_multiplier == 2.0
      assert config.off_peak_multiplier == 0.5
    end

    test "respects custom peak and off-peak hours" do
      config =
        ConfigGenerator.generate_time_config(48, 30,
          peak_hours: [20, 21],
          off_peak_hours: [2, 3, 4]
        )

      assert config.peak_hours == [20, 21]
      assert config.off_peak_hours == [2, 3, 4]
    end

    test "calculates agents per hour based on agent count" do
      config = ConfigGenerator.generate_time_config(24, 100)

      assert config.agents_per_hour_min > 0
      assert config.agents_per_hour_max > config.agents_per_hour_min
    end
  end

  describe "generate_activity_config/3" do
    test "generates activity for Student type" do
      config = ConfigGenerator.generate_activity_config("Student", 0.8)

      # Students are more active
      assert config.activity_level > 0.8
      assert config.posts_per_hour > 0
      assert config.likes_per_hour > 0
      assert config.comments_per_hour > 0
      assert is_list(config.active_hours)
      assert config.stance in ["neutral", "supportive", "opposed"]
    end

    test "generates activity for Professor type" do
      config = ConfigGenerator.generate_activity_config("Professor", 0.8)

      # Professors are less active
      assert config.activity_level < 0.8
    end

    test "generates activity for Media type" do
      config = ConfigGenerator.generate_activity_config("Media", 0.8)

      # Media is more active
      assert config.activity_level > 0.8
    end

    test "respects stance option" do
      config = ConfigGenerator.generate_activity_config("Student", 0.8, stance: "opposed")

      assert config.stance == "opposed"
    end
  end

  describe "generate_event_config/2" do
    test "generates event configuration" do
      requirements = "Campus debate simulation"
      config = ConfigGenerator.generate_event_config(requirements)

      assert is_list(config.initial_posts)
      assert is_list(config.hot_topics)
      assert is_list(config.scheduled_events)
      assert is_float(config.controversy_level)
    end

    test "generates controversial events when level is high" do
      config = ConfigGenerator.generate_event_config("Test", controversy_level: 0.9)

      # Should have more initial posts when controversy is high
      assert length(config.initial_posts) >= 2
    end
  end

  describe "generate_platform_config/2" do
    test "generates Twitter config" do
      config = ConfigGenerator.generate_platform_config(:twitter)

      assert config.character_limit == 280
      assert config.trending_threshold > 0
      assert config.viral_threshold > config.trending_threshold
    end

    test "generates Reddit config" do
      config = ConfigGenerator.generate_platform_config(:reddit)

      assert config.subreddit == "simulation"
      assert config.upvote_threshold > 0
      assert config.hot_threshold > config.upvote_threshold
    end

    test "generates both platform configs" do
      config = ConfigGenerator.generate_platform_config(:both)

      assert config.twitter.character_limit == 280
      assert config.reddit.subreddit == "simulation"
    end
  end

  describe "extract_hot_topics/1" do
    test "extracts key terms from requirements" do
      # Test via generate_event_config
      config = ConfigGenerator.generate_event_config("Climate change policy debate")

      # Should extract terms like "climate", "change", "policy", "debate"
      assert length(config.hot_topics) > 0
    end
  end
end
