defmodule Miroex.AI.Openrouter.Client do
  @moduledoc false

  def chat(api_key, base_url, messages, model) do
    body = %{
      model: model,
      messages: messages,
      temperature: 0.7
    }

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    case Req.post("#{base_url}/chat/completions",
           json: body,
           headers: headers,
           receive_timeout: 120_000
         ) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => message} | _]}}} ->
        {:ok, message}

      {:ok, %{body: %{"error" => error}}} ->
        {:error, error}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def chat_stream(api_key, base_url, messages, model, caller_pid) do
    body = %{
      model: model,
      messages: messages,
      temperature: 0.7,
      stream: true
    }

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    url = "#{base_url}/chat/completions"

    spawn(fn ->
      case :httpc.request(
             :post,
             {String.to_charlist(url), headers, ~c"application/json", Jason.encode!(body)},
             [],
             []
           ) do
        {:ok, {{_version, 200, _status}, _headers, body}} ->
          send(caller_pid, {:stream, body})
          send(caller_pid, {:stream, :done})

        {:error, reason} ->
          send(caller_pid, {:error, reason})
      end
    end)

    :ok
  end
end
