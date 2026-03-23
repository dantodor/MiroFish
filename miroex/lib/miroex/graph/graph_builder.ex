defmodule Miroex.Graph.GraphBuilder do
  @moduledoc """
  Build knowledge graph in Memgraph from text chunks and ontology.
  """
  alias Miroex.Memgraph

  @spec build(String.t(), map(), [String.t()]) :: {:ok, String.t()} | {:error, term()}
  def build(graph_id, ontology, chunks) when is_list(chunks) do
    cypher_create_graph = """
    CREATE (g:Graph {id: $graph_id, created_at: datetime()})
    RETURN g.id as id
    """

    case Memgraph.query(cypher_create_graph, %{graph_id: graph_id}) do
      {:ok, _} ->
        build_entities_and_relations(graph_id, ontology, chunks)
        {:ok, graph_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_entities_and_relations(graph_id, ontology, chunks) do
    entity_types = ontology["entity_types"] || []
    edge_types = ontology["edge_types"] || []

    chunks
    |> Enum.with_index()
    |> Enum.each(fn {chunk, idx} ->
      entities = extract_entities(chunk, entity_types)
      relations = extract_relations(chunk, entities, edge_types)

      store_entities(graph_id, entities, idx)
      store_relations(graph_id, relations)
    end)
  end

  defp extract_entities(_chunk, []) do
    []
  end

  defp extract_entities(chunk, entity_types) do
    entity_prompt = """
    Extract entities from this text. For each entity provide:
    - name: the entity name
    - type: the entity type (one of: #{Enum.join(entity_types, ", ")})

    Return as JSON array: [{"name": "...", "type": "..."}, ...]
    Text: #{String.slice(chunk, 0, 2000)}
    """

    messages = [
      %{role: "user", content: entity_prompt}
    ]

    case Miroex.AI.Openrouter.chat(messages) do
      {:ok, %{content: content}} ->
        parse_entities(content)

      {:error, _} ->
        []
    end
  end

  defp parse_entities(content) do
    case Jason.decode(content) do
      {:ok, entities} when is_list(entities) -> entities
      _ -> []
    end
  rescue
    _ -> []
  end

  defp extract_relations(_chunk, [], _edge_types) do
    []
  end

  defp extract_relations(chunk, entities, edge_types) do
    if length(entities) < 2 do
      []
    else
      relation_prompt = """
      Identify relationships between these entities. Available relationship types: #{Enum.join(edge_types, ", ")}

      Entities: #{Jason.encode!(entities)}
      Text: #{String.slice(chunk, 0, 2000)}

      Return as JSON array: [{"from": "entity1", "to": "entity2", "type": "relation_type"}, ...]
      """

      messages = [
        %{role: "user", content: relation_prompt}
      ]

      case Miroex.AI.Openrouter.chat(messages) do
        {:ok, %{content: content}} ->
          parse_relations(content)

        {:error, _} ->
          []
      end
    end
  end

  defp parse_relations(content) do
    case Jason.decode(content) do
      {:ok, relations} when is_list(relations) -> relations
      _ -> []
    end
  rescue
    _ -> []
  end

  defp store_entities(_graph_id, [], _chunk_idx) do
    :ok
  end

  defp store_entities(graph_id, entities, chunk_idx) do
    Enum.each(entities, fn entity ->
      cypher = """
      MATCH (g:Graph {id: $graph_id})
      CREATE (e:Entity {
        name: $name,
        type: $type,
        chunk_idx: $chunk_idx,
        properties: $properties
      })
      CREATE (g)-[:HAS_ENTITY]->(e)
      """

      Memgraph.query(cypher, %{
        graph_id: graph_id,
        name: entity["name"],
        type: entity["type"],
        chunk_idx: chunk_idx,
        properties: Jason.encode!(entity)
      })
    end)
  end

  defp store_relations(_graph_id, []) do
    :ok
  end

  defp store_relations(_graph_id, relations) do
    relations
    |> Enum.each(fn rel ->
      cypher = """
      MATCH (e1:Entity {name: $from, type: $from_type})
      MATCH (e2:Entity {name: $to, type: $to_type})
      MERGE (e1)-[r:RELATES {type: $rel_type}]->(e2)
      """

      Memgraph.query(cypher, %{
        from: rel["from"],
        from_type: rel["from_type"] || "UNKNOWN",
        to: rel["to"],
        to_type: rel["to_type"] || "UNKNOWN",
        rel_type: rel["type"]
      })
    end)
  end
end
