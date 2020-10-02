defmodule Front.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Front.Repo,
      # Start the Telemetry supervisor
      FrontWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Front.PubSub},
      # Start the Endpoint (http/https)
      FrontWeb.Endpoint
      # Start a worker by calling: Front.Worker.start_link(arg)
      # {Front.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Front.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    FrontWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
