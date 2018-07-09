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
    slow_exit_validator_block_margin = Application.get_env(:omisego_watcher, :slow_exit_validator_block_margin)

    depositer_config = get_event_listener_config(:depositer)
    exiter_config = get_event_listener_config(:exiter)

    children = [
      # Start the Ecto repository
      supervisor(OmiseGOWatcher.Repo, []),
      # Start workers
      {OmiseGO.API.State, []},
      {OmiseGOWatcher.Eventer, []},
      {OmiseGO.API.RootChainCoordinator, MapSet.new([:depositer, :exiter, :fast_validator, :slow_validator])},
      worker(
        OmiseGO.API.EthereumEventListener,
        [depositer_config, &OmiseGO.Eth.get_deposits/2, &OmiseGO.API.State.deposit/1],
        id: :depositer
      ),
      worker(
        OmiseGO.API.EthereumEventListener,
        [exiter_config, &OmiseGO.Eth.get_exits/2, &OmiseGO.API.State.exit_utxos/1],
        id: :exiter
      ),
      worker(
        OmiseGOWatcher.ExitValidator,
        [&OmiseGO.DB.last_fast_exit_block_height/0, fn _ -> :ok end, 0, :last_fast_exit_block_height, :fast_validator],
        id: :fast_validator
      ),
      worker(
        OmiseGOWatcher.ExitValidator,
        [
          &OmiseGO.DB.last_slow_exit_block_height/0,
          &slow_validator_utxo_exists_callback(&1),
          slow_exit_validator_block_margin,
          :last_slow_exit_block_height,
          :slow_validator
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
    IO.puts("Slow validator spends #{inspect(utxo_exit)}")

    with :ok <- OmiseGO.API.State.exit_if_not_spent(utxo_exit) do
      :ok
    else
      :utxo_does_not_exist ->
        :ok = OmiseGOWatcher.ChainExiter.exit()
        :child_chain_exit
    end
  end

  defp get_event_listener_config(service_name) do
    %{
      block_finality_margin: Application.get_env(:omisego_api, :ethereum_event_block_finality_margin),
      service_name: service_name
    }
  end
end
