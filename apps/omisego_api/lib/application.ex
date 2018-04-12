defmodule OmiseGO.API.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec

  def start(_type, _args) do
    depositor_config = get_depositor_config()
    exiter_config = get_exiter_config()
    children = [
      supervisor(Phoenix.PubSub.PG2, [:eventer, []]),
      {OmiseGO.API.State, []},
      {OmiseGO.API.BlockQueue.Server, []},
      {OmiseGO.API.FreshBlocks, []},
      worker(OmiseGO.API.EthereumEventListener, [depositor_config, &State.deposit/1], [id: :depositor]),
      worker(OmiseGO.API.EthereumEventListener, [exiter_config, &State.exit_utxos/1], [id: :exiter])
    ]
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  defp get_depositor_config do
    %{
      block_finality_margin: Application.get_env(:omisego_api, :depositor_block_finality_margin),
      max_blocks_in_fetch: Application.get_env(:omisego_api, :depositor_max_block_range_in_deposits_query),
      get_events_interval: Application.get_env(:omisego_api, :depositor_get_deposits_interval_ms)
    }
  end

  defp get_exiter_config do
    %{
      block_finality_margin: Application.get_env(:omisego_api, :exiter_block_finality_margin),
      max_blocks_in_fetch: Application.get_env(:omisego_api, :exiter_max_block_range_in_deposits_query),
      get_events_interval: Application.get_env(:omisego_api, :exiter_get_deposits_interval_ms)
    }
  end
end
