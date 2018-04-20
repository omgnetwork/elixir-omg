defmodule OmiseGOWatcher.Application do
  @moduledoc"""
  See https://hexdocs.pm/elixir/Application.html
  for more information on OTP Applications
  """
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(OmiseGOWatcher.Repo, []),
      # Start the endpoint when the application starts
      supervisor(OmiseGOWatcherWeb.Endpoint, []),
      {OmiseGO.API.State, []},
      # Start workers
      worker(OmiseGOWatcher.ExitValidator, []),
      worker(
        OmiseGO.API.EthereumEventListener,
        [get_event_listener_config(), &OmiseGO.Eth.get_exits/3, &ExitValidator.validate_exit/1],
        [id: :exiter]
      )
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

  defp get_event_listener_config do
    %{
      block_finality_margin: Application.get_env(:omisego_api, :ethereum_event_block_finality_margin),
      max_blocks_in_fetch: Application.get_env(:omisego_api, :ethereum_event_max_block_range_in_deposits_query),
      get_events_interval: Application.get_env(:omisego_api, :ethereum_event_get_deposits_interval_ms)
    }
  end
end
