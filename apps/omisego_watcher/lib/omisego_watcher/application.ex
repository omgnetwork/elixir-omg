defmodule OmiseGOWatcher.Application do
  @moduledoc """
  See https://hexdocs.pm/elixir/Application.html
  for more information on OTP Applications
  """
  use Application
  use OmiseGO.API.LoggerExt

  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    slow_exit_validator_block_margin = Application.get_env(:omisego_api, :slow_exit_validator_block_margin)

    event_listener_config = %{
      block_finality_margin: Application.get_env(:omisego_api, :ethereum_event_block_finality_margin),
      max_blocks_in_fetch: Application.get_env(:omisego_api, :ethereum_event_max_block_range_in_deposits_query),
      get_events_interval: Application.get_env(:omisego_api, :ethereum_event_get_deposits_interval_ms)
    }

    children = [
      # Start the Ecto repository
      supervisor(OmiseGOWatcher.Repo, []),
      # Start workers
      {OmiseGO.API.State, []},
      {OmiseGOWatcher.Eventer, []},
      worker(
        OmiseGO.API.EthereumEventListener,
        [event_listener_config, &OmiseGO.Eth.get_deposits/2, &OmiseGO.API.State.deposit/1],
        id: :depositor
      ),
      worker(
        OmiseGO.API.EthereumEventListener,
        [event_listener_config, &OmiseGO.Eth.get_exits/2, &OmiseGO.API.State.exit_utxos/1],
        id: :exiter
      ),
      worker(
        OmiseGOWatcher.ExitValidator,
        [&OmiseGO.DB.last_fast_exit_block_height/0, fn _ -> :ok end, 0, :last_fast_exit_block_height],
        id: :fast_validator
      ),
      worker(
        OmiseGOWatcher.ExitValidator,
        [
          &OmiseGO.DB.last_slow_exit_block_height/0,
          &slow_validator_utxo_exists_callback(&1),
          slow_exit_validator_block_margin,
          :last_slow_exit_block_height
        ],
        id: :slow_validator
      ),
      worker(
        OmiseGOWatcher.BlockGetter,
        [[]],
        restart: :transient,
        id: :block_getter
      ),

      # Start the endpoint when the application starts
      supervisor(OmiseGOWatcherWeb.Endpoint, [])
    ]

    _ = Logger.info(fn -> "Started application OmiseGOWatcher.Application" end)

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

  defp slow_validator_utxo_exists_callback(utxo_exit) do
    with :ok <- OmiseGO.API.State.exit_if_not_spent(utxo_exit) do
      :ok
    else
      :utxo_does_not_exist ->
        :ok = OmiseGOWatcher.ChainExiter.exit()
        :child_chain_exit
    end
  end
end
