defmodule OmiseGO.API.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec
  alias OmiseGO.API.State

  def start(_type, _args) do
    event_listener_config = get_event_listener_config()

    children = [
      supervisor(Phoenix.PubSub.PG2, [:eventer, []]),
      {OmiseGO.API.State, []},
      {OmiseGO.API.BlockQueue.Server, []},
      {OmiseGO.API.FreshBlocks, []},
      worker(
        OmiseGO.API.EthereumEventListener,
        [event_listener_config, &OmiseGO.Eth.get_deposits/2, &State.deposit/1],
        id: :depositor
      ),
      worker(
        OmiseGO.API.EthereumEventListener,
        [event_listener_config, &OmiseGO.Eth.get_exits/2, &State.exit_utxos/1],
        id: :exiter
      )
    ]

    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  def init() do
    path = Application.get_env(:omisego_db, :leveldb_path)
    File.mkdir(path)

    if !Enum.empty?(File.ls!(path)) do
      raise("creatin omisego_db \n\tfolder should be empty:\t" <> path)
    end

    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)
    :ok = OmiseGO.DB.multi_update([{:put, :last_deposit_block_height, 0}])
    :ok = OmiseGO.DB.multi_update([{:put, :child_top_block_number, 0}])
    started_apps |> Enum.reverse() |> Enum.map(fn app -> :ok = Application.stop(app) end)
  end

  defp get_event_listener_config do
    %{
      block_finality_margin: Application.get_env(:omisego_api, :ethereum_event_block_finality_margin),
      max_blocks_in_fetch: Application.get_env(:omisego_api, :ethereum_event_max_block_range_in_deposits_query),
      get_events_interval: Application.get_env(:omisego_api, :ethereum_event_get_deposits_interval_ms)
    }
  end
end
