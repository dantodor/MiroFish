defmodule Miroex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Registry.ReportProgress},
      MiroexWeb.Telemetry,
      Miroex.Repo,
      {DNSCluster, query: Application.get_env(:miroex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Miroex.PubSub},
      {Finch, name: Miroex.Finch},
      Miroex.AI.Openrouter,
      Miroex.Simulation.LLMGateway,
      Miroex.Simulation.AgentRegistry,
      Miroex.Simulation.AgentSupervisor,
      MiroexWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Miroex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MiroexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
