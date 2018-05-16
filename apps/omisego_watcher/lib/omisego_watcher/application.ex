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
      worker(
        OmiseGOWatcher.ExitValidator,
        [OmiseGO.DB.last_fast_exit_block_height(), fn _ -> :ok end, 0, :last_fast_exit_block_height],
        id: :fast_validator
      ),
      worker(
        OmiseGOWatcher.ExitValidator,
        [
          OmiseGO.DB.last_slow_exit_block_height(),
          &slow_validator_utxo_exists_callback(&1),
          slow_exit_validator_block_margin,
          :last_slow_exit_block_height
        ],
        id: :slow_validator
      ),
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
