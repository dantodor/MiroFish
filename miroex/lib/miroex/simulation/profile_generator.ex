defmodule Miroex.Simulation.ProfileGenerator do
  @moduledoc """
  Generate OASIS agent profiles from Memgraph entities.
  """
  alias Miroex.Graph.EntityReader
  alias Miroex.AI.Openrouter

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

  defp generate_twitter_profile(entity) do
    persona = generate_persona(entity)

    %{
      user_id: String.length(entity["name"]),
      name: entity["name"],
      username: generate_username(entity["name"]),
      user_char: persona,
      description: persona
    }
  end

  defp generate_reddit_profile(entity) do
    persona = generate_persona(entity)

    %{
      user_id: String.length(entity["name"]),
      username: generate_username(entity["name"]),
      name: entity["name"],
      bio: persona,
      persona: persona,
      age: Enum.random(18..65),
      gender: Enum.random(["male", "female", "non-binary"]),
      mbti: Enum.random(["INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP"]),
      stance: Enum.random(["supportive", "neutral", "critical"])
    }
  end

  defp generate_persona(entity) do
    prompt = """
    Create a brief persona description (2-3 sentences) for a social media user representing this entity:
    Name: #{entity["name"]}
    Type: #{entity["type"]}

    Return just the persona description.
    """

    case Openrouter.chat([%{role: "user", content: prompt}]) do
      {:ok, %{content: persona}} -> String.trim(persona)
      {:error, _} -> "#{entity["name"]} is a #{entity["type"]}"
    end
  end

  defp generate_username(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/, "_")
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
    if String.contains?(value, ",") or String.contains?(value, "\"") or
         String.contains?(value, "\n") do
      "\"#{String.replace(value, "\"", "\"\"")}\""
    else
      value
    end
  end

  defp csv_escape(value), do: to_string(value)
end
