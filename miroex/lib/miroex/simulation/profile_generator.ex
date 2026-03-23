defmodule Miroex.Simulation.ProfileGenerator do
  @moduledoc """
  Generate OASIS agent profiles from Memgraph entities.

  Enhanced to create detailed personas that mirror the Python implementation:
  - Rich entity context from Memgraph
  - Individual vs group entity distinction
  - Detailed persona prompts with LLM retry logic
  - JSON parsing with error recovery
  """
  alias Miroex.Graph.EntityReader
  alias Miroex.AI.{Openrouter, JSONHelper}

  @individual_types [
    "student",
    "alumni",
    "professor",
    "person",
    "publicfigure",
    "expert",
    "faculty",
    "official",
    "journalist",
    "activist",
    "researcher",
    "teacher",
    "doctor",
    "engineer",
    "artist"
  ]

  @group_types [
    "university",
    "governmentagency",
    "organization",
    "ngo",
    "mediaoutlet",
    "company",
    "institution",
    "group",
    "community",
    "government",
    "party",
    "association",
    "agency"
  ]

  @mbti_types [
    "INTJ",
    "INTP",
    "ENTJ",
    "ENTP",
    "INFJ",
    "INFP",
    "ENFJ",
    "ENFP",
    "ISTJ",
    "ISFJ",
    "ESTJ",
    "ESFJ",
    "ISTP",
    "ISFP",
    "ESTP",
    "ESFP"
  ]

  @countries [
    "中国",
    "美国",
    "英国",
    "日本",
    "德国",
    "法国",
    "加拿大",
    "澳大利亚",
    "巴西",
    "印度"
  ]

  @spec generate_twitter_profiles(String.t()) :: {:ok, [map()], String.t()}
  def generate_twitter_profiles(graph_id) do
    with {:ok, entities} <- EntityReader.get_entities(graph_id),
         {:ok, _entity_types} <- EntityReader.get_entity_types(graph_id) do
      profiles = Enum.map(entities, &generate_twitter_profile/1)
      csv_content = profiles_to_csv(profiles)
      {:ok, profiles, csv_content}
    end
  end

  @spec generate_reddit_profiles(String.t()) :: {:ok, [map()], String.t()}
  def generate_reddit_profiles(graph_id) do
    with {:ok, entities} <- EntityReader.get_entities(graph_id) do
      profiles = Enum.map(entities, &generate_reddit_profile/1)
      json_content = Jason.encode!(profiles, pretty: true)
      {:ok, profiles, json_content}
    end
  end

  @spec generate_profiles_from_entities([map()], String.t()) :: [map()]
  def generate_profiles_from_entities(entities, graph_id) do
    entities
    |> Enum.map(fn entity ->
      entity_with_context =
        case EntityReader.get_entity_with_context(graph_id, entity["name"]) do
          {:ok, ctx} -> Map.merge(entity, ctx)
          _ -> entity
        end

      if is_individual_entity?(entity_with_context["type"]) do
        generate_individual_profile(entity_with_context)
      else
        generate_group_profile(entity_with_context)
      end
    end)
  end

  defp generate_twitter_profile(entity) do
    entity_type = entity["type"] || "Entity"
    is_individual = is_individual_entity?(entity_type)

    profile_data =
      if is_individual do
        generate_individual_profile(entity)
      else
        generate_group_profile(entity)
      end

    %{
      user_id: abs(String.length(entity["name"])),
      name: entity["name"],
      username: generate_username(entity["name"]),
      user_char:
        profile_data[:persona] || profile_data[:bio] || "#{entity["name"]} is a #{entity_type}",
      description: profile_data[:bio] || "#{entity["name"]} is a #{entity_type}"
    }
  end

  defp generate_reddit_profile(entity) do
    entity_type = entity["type"] || "Entity"
    is_individual = is_individual_entity?(entity_type)

    profile_data =
      if is_individual do
        generate_individual_profile(entity)
      else
        generate_group_profile(entity)
      end

    %{
      user_id: abs(String.length(entity["name"])),
      username: generate_username(entity["name"]),
      name: entity["name"],
      bio: profile_data[:bio] || "#{entity["name"]} is a #{entity_type}",
      persona:
        profile_data[:persona] || profile_data[:bio] || "#{entity["name"]} is a #{entity_type}",
      karma: 1000,
      created_at: Date.to_iso8601(Date.utc_today()),
      age: profile_data[:age] || Enum.random(18..65),
      gender: normalize_gender(profile_data[:gender]),
      mbti: profile_data[:mbti] || Enum.random(@mbti_types),
      country: profile_data[:country] || Enum.random(@countries),
      profession: profile_data[:profession] || entity_type
    }
  end

  @doc """
  Check if entity type represents an individual (person) vs group/institution.
  """
  @spec is_individual_entity?(String.t()) :: boolean()
  def is_individual_entity?(type) when is_binary(type) do
    type_lower = String.downcase(type)
    Enum.any?(@individual_types, &String.contains?(type_lower, &1))
  end

  def is_individual_entity?(_), do: false

  @doc """
  Check if entity type represents a group/institution.
  """
  @spec is_group_entity?(String.t()) :: boolean()
  def is_group_entity?(type) when is_binary(type) do
    type_lower = String.downcase(type)
    Enum.any?(@group_types, &String.contains?(type_lower, &1))
  end

  def is_group_entity?(_), do: false

  defp generate_individual_profile(entity) do
    context = build_entity_context(entity)
    prompt = build_individual_persona_prompt(entity, context)

    case generate_persona_with_retry(prompt, temperature: 0.7) do
      {:ok, persona_data} ->
        %{
          bio: persona_data["bio"] || extract_summary(entity),
          persona: persona_data["persona"] || persona_data["bio"] || extract_summary(entity),
          age: parse_integer(persona_data["age"]),
          gender: persona_data["gender"],
          mbti: persona_data["mbti"],
          country: persona_data["country"],
          profession: persona_data["profession"],
          interested_topics: parse_array(persona_data["interested_topics"])
        }

      {:error, _} ->
        generate_fallback_individual_profile(entity)
    end
  end

  defp generate_group_profile(entity) do
    context = build_entity_context(entity)
    prompt = build_group_persona_prompt(entity, context)

    case generate_persona_with_retry(prompt, temperature: 0.7) do
      {:ok, persona_data} ->
        %{
          bio: persona_data["bio"] || extract_summary(entity),
          persona: persona_data["persona"] || persona_data["bio"] || extract_summary(entity),
          age: 30,
          gender: "other",
          mbti: persona_data["mbti"] || "ISTJ",
          country: persona_data["country"] || "中国",
          profession: persona_data["profession"] || entity["type"] || "Organization",
          interested_topics: parse_array(persona_data["interested_topics"])
        }

      {:error, _} ->
        generate_fallback_group_profile(entity)
    end
  end

  defp generate_persona_with_retry(prompt, opts, attempts \\ 3)

  defp generate_persona_with_retry(_prompt, _opts, 0) do
    {:error, :all_attempts_failed}
  end

  defp generate_persona_with_retry(prompt, opts, attempts) when attempts > 0 do
    temp = Keyword.get(opts, :temperature, 0.7)
    adjusted_temp = temp - 0.1 * (3 - attempts)

    messages = [
      %{role: "system", content: system_prompt()},
      %{role: "user", content: prompt}
    ]

    case Openrouter.chat(messages, "openai/gpt-4o-mini") do
      {:ok, %{content: content}} ->
        case JSONHelper.parse_with_fallback(content, required_fields: ["bio", "persona"]) do
          {:ok, persona_data} when persona_data != %{} ->
            {:ok, persona_data}

          _ when attempts > 1 ->
            generate_persona_with_retry(prompt, opts, attempts - 1)

          _ ->
            {:error, :parse_failed}
        end

      {:error, reason} when attempts > 1 ->
        Process.sleep(1000 * (4 - attempts))
        generate_persona_with_retry(prompt, opts, attempts - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp system_prompt do
    """
    You are a social media user persona generation expert. Generate detailed, realistic personas for opinion simulation, maximizing fidelity to known reality. Return valid JSON format with all string values properly escaped. Use Chinese for content except gender which must be "male", "female", or "other".
    """
  end

  defp build_entity_context(entity) do
    parts = []

    if entity["properties"] do
      props =
        case entity["properties"] do
          p when is_binary(p) ->
            case Jason.decode(p) do
              {:ok, m} -> m
              _ -> %{}
            end

          p when is_map(p) ->
            p

          _ ->
            %{}
        end

      if props != %{} do
        attrs =
          props
          |> Enum.reject(fn {_, v} -> v == nil or v == "" end)
          |> Enum.map(fn {k, v} -> "- #{k}: #{v}" end)

        if attrs != [] do
          parts = parts ++ ["### Entity Attributes\n" <> String.join(attrs, "\n")]
        end
      end
    end

    if entity["relations"] && entity["relations"] != [] do
      rels =
        entity["relations"]
        |> Enum.reject(fn r -> r.fact == "" or r.fact == nil end)
        |> Enum.map(fn r ->
          case r.direction do
            :outgoing -> "#{entity["name"]} --[#{r.type}]--> #{r.related_to}"
            :incoming -> "#{r.related_to} --[#{r.type}]--> #{entity["name"]}"
          end
        end)

      if rels != [] do
        parts = parts ++ ["### Relations\n" <> String.join(rels, "\n")]
      end
    end

    if entity["related_entities"] && entity["related_entities"] != [] do
      related =
        entity["related_entities"]
        |> Enum.map(fn e ->
          type_str = if e["type"], do: " (#{e["type"]})", else: ""
          "- #{e["name"]}#{type_str}"
        end)

      parts = parts ++ ["### Related Entities\n" <> String.join(related, "\n")]
    end

    Enum.join(parts, "\n\n")
  end

  defp build_individual_persona_prompt(entity, context) do
    entity_name = entity["name"] || ""
    entity_type = entity["type"] || "Entity"
    summary = extract_summary(entity)
    context_str = if context != "", do: context, else: "No additional context available"

    """
    Generate a detailed social media persona for an individual entity, maximizing fidelity to known reality.

    Entity Name: #{entity_name}
    Entity Type: #{entity_type}
    Summary: #{summary}

    Context Information:
    #{context_str}

    Generate JSON with these fields:

    1. bio: Social media bio, approximately 200 characters in Chinese
    2. persona: Detailed persona description (2000+ characters in Chinese), must include:
       - Basic info (age, education, location)
       - Background (important experiences, social connections)
       - Personality traits (MBTI type, core traits, emotional expression)
       - Social media behavior (posting frequency, content preferences, interaction style)
       - Stance and opinions (attitude toward topics, what might anger or move them)
       - Unique characteristics (catchphrases, special experiences, personal interests)
       - Memory (important part of persona - their involvement and reactions to events)
    3. age: Age as an integer
    4. gender: Must be "male" or "female" (English)
    5. mbti: MBTI type (e.g., INTJ, ENFP)
    6. country: Country in Chinese
    7. profession: Profession/occupation
    8. interested_topics: Array of topics this person is interested in

    Important:
    - All string values must not contain unescaped newlines
    - persona must be a continuous text description
    - Use Chinese (except gender which must be English)
    - age must be a valid integer
    - gender must be "male" or "female"
    """
  end

  defp build_group_persona_prompt(entity, context) do
    entity_name = entity["name"] || ""
    entity_type = entity["type"] || "Entity"
    summary = extract_summary(entity)
    context_str = if context != "", do: context, else: "No additional context available"

    """
    Generate a detailed social media account persona for an institution/group entity, maximizing fidelity to known reality.

    Entity Name: #{entity_name}
    Entity Type: #{entity_type}
    Summary: #{summary}

    Context Information:
    #{context_str}

    Generate JSON with these fields:

    1. bio: Official account bio, approximately 200 characters in Chinese, professional tone
    2. persona: Detailed account persona description (2000+ characters in Chinese), must include:
       - Basic institution info (official name, nature, founding background, main functions)
       - Account positioning (account type, target audience, core function)
       - Speaking style (language characteristics, common expressions, taboos)
       - Content characteristics (content type, posting frequency, active time periods)
       - Stance and attitude (official position on core topics, handling of controversies)
       - Special notes (represented group profile, operational habits)
       - Institutional memory (important part - institution's involvement and past actions/reactions to events)
    3. age: Always 30 (virtual age for institutional accounts)
    4. gender: Always "other" (for institutional accounts)
    5. mbti: MBTI type describing account style, e.g., ISTJ for rigorous/conservative
    6. country: Country in Chinese
    7. profession: Institutional function/role description
    8. interested_topics: Array of topics this account follows

    Important:
    - All string values must not contain unescaped newlines
    - persona must be a continuous text description
    - Use Chinese (except gender which must be "other")
    - age must be integer 30, gender must be "other"
    """
  end

  defp generate_fallback_individual_profile(entity) do
    %{
      bio: extract_summary(entity),
      persona: extract_summary(entity),
      age: Enum.random(18..65),
      gender: Enum.random(["male", "female"]),
      mbti: Enum.random(@mbti_types),
      country: Enum.random(@countries),
      profession: entity["type"] || "Individual",
      interested_topics: ["Social Issues", "General"]
    }
  end

  defp generate_fallback_group_profile(entity) do
    %{
      bio: extract_summary(entity),
      persona: extract_summary(entity),
      age: 30,
      gender: "other",
      mbti: "ISTJ",
      country: "中国",
      profession: entity["type"] || "Organization",
      interested_topics: ["Public Policy", "Community"]
    }
  end

  defp extract_summary(entity) do
    case entity["properties"] do
      p when is_binary(p) ->
        case Jason.decode(p) do
          {:ok, m} ->
            Map.get(m, "summary", "") || Map.get(m, "description", "") || entity["name"] || ""

          _ ->
            entity["name"] || ""
        end

      p when is_map(p) ->
        Map.get(p, "summary", "") || Map.get(p, "description", "") || entity["name"] || ""

      _ ->
        entity["name"] || ""
    end
  end

  defp parse_integer(nil), do: Enum.random(18..65)
  defp parse_integer(v) when is_integer(v), do: v

  defp parse_integer(v) when is_binary(v) do
    case Integer.parse(v) do
      {i, _} -> i
      _ -> Enum.random(18..65)
    end
  end

  defp parse_integer(_), do: Enum.random(18..65)

  defp parse_array(nil), do: []
  defp parse_array(v) when is_list(v), do: v

  defp parse_array(v) when is_binary(v) do
    v
    |> String.split(~r/[,;]/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_array(_), do: []

  defp normalize_gender(nil), do: "other"
  defp normalize_gender("male"), do: "male"
  defp normalize_gender("female"), do: "female"

  defp normalize_gender(v) when is_binary(v) do
    case String.downcase(v) do
      g when g in ["male", "男"] -> "male"
      g when g in ["female", "女"] -> "female"
      _ -> "other"
    end
  end

  defp normalize_gender(_), do: "other"

  defp generate_username(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/u, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
    |> then(&"#{&1}_#{Enum.random(100..999)}")
  end

  defp profiles_to_csv(profiles) do
    headers = ["user_id", "name", "username", "user_char", "description"]

    rows =
      Enum.map(profiles, fn p ->
        [p.user_id, p.name, p.username, p.user_char, p.description]
        |> Enum.map(&csv_escape/1)
        |> Enum.join(",")
      end)

    [Enum.join(headers, ","), rows]
    |> Enum.join("\n")
  end

  defp csv_escape(value) when is_binary(value) do
    value = String.replace(value, "\n", " ")

    if String.contains?(value, ",") or String.contains?(value, "\"") do
      "\"#{String.replace(value, "\"", "\"\"")}\""
    else
      value
    end
  end

  defp csv_escape(value), do: to_string(value)
end
