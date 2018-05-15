defmodule OmiseGOWatcher.Application do
  @moduledoc """
  See https://hexdocs.pm/elixir/Application.html
  for more information on OTP Applications
  """
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    slow_exit_validator_block_margin = Application.get_env(:omisego_api, :slow_exit_validator_block_margin)

    children = [
      # Start the Ecto repository
      supervisor(OmiseGOWatcher.Repo, []),
      # Start workers
      {OmiseGO.API.State, []},
      worker(OmiseGOWatcher.FastExitValidator, []),
      worker(OmiseGOWatcher.SlowExitValidator, [slow_exit_validator_block_margin]),
      # Start the endpoint when the application starts
      supervisor(OmiseGOWatcherWeb.Endpoint, [])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OmiseGOWatcher.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OmiseGOWatcherWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
