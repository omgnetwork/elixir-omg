defmodule OmiseGO.API.Application do
  @moduledoc """
  The application here is the Child chain server and its API.
  See here (children) for the processes that compose into the Child Chain server.
  """

  use Application
  use OmiseGO.API.LoggerExt
  import Supervisor.Spec
  alias OmiseGO.API.State

  def start(_type, _args) do
    event_listener_config = get_event_listener_config()

    children = [
      {OmiseGO.API.State, []},
      {OmiseGO.API.BlockQueue.Server, []},
      {OmiseGO.API.FreshBlocks, []},
      {OmiseGO.API.FeeChecker, []},
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

    _ = Logger.info(fn -> "Started application OmiseGO.API.Application" end)
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  defp get_event_listener_config do
    %{
      block_finality_margin: Application.get_env(:omisego_api, :ethereum_event_block_finality_margin),
      max_blocks_in_fetch: Application.get_env(:omisego_api, :ethereum_event_max_block_range_in_deposits_query),
      get_events_interval: Application.get_env(:omisego_api, :ethereum_event_get_deposits_interval_ms)
    }
  end
end
