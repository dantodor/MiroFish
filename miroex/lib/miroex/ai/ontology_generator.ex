defmodule Miroex.AI.OntologyGenerator do
  @moduledoc """
  Generate ontology (entity types and relationship types) from text using LLM.
  """
  alias Miroex.AI.Openrouter

  @system_prompt """
  You are an ontology extraction expert. Analyze the provided text and extract:
  1. Entity Types - The main categories of entities mentioned (e.g., Person, Organization, Location, Event, Concept)
  2. Relationship Types - How entities relate to each other (e.g., works_for, lives_in, created_by, causes)

  Return your response as a JSON object with:
  {
    "entity_types": ["EntityType1", "EntityType2", ...],
    "edge_types": ["RelationshipType1", "RelationshipType2", ...],
    "analysis_summary": "Brief summary of what this text is about"
  }

  Be thorough but concise. Extract 3-10 entity types and 3-10 relationship types.
  """

  @spec generate(String.t()) :: {:ok, map()} | {:error, term()}
  def generate(text) do
    messages = [
      %{role: "system", content: @system_prompt},
      %{
        role: "user",
        content: "Extract ontology from this text:\n\n" <> String.slice(text, 0, 10000)
      }
    ]

    case Openrouter.chat(messages) do
      {:ok, %{content: content}} ->
        parse_ontology_response(content)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_ontology_response(content) do
    case Jason.decode(content) do
      {:ok, %{"entity_types" => _, "edge_types" => _} = ontology} ->
        {:ok, ontology}

      {:ok, other} ->
        {:error, {:invalid_format, other}}

      {:error, reason} ->
        {:error, {:json_parse_error, reason, content}}
    end
  end
end
