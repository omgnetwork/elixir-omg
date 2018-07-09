defmodule OmiseGO.API.EthereumEventListener do
  @moduledoc """
  Periodically fetches events made on dynamically changing block range
  on parent chain and feeds them to state.
  For code simplicity it listens for events in blocks with a configured finality margin.
  """

  alias OmiseGO.API.EthereumEventListener.Core
  alias OmiseGO.API.RootChainCoordinator
  alias OmiseGO.Eth
  use OmiseGO.API.LoggerExt

  ### Client

  def start_link(config, get_events_callback, process_events_callback) do
    GenServer.start_link(__MODULE__, {config, get_events_callback, process_events_callback})
  end

  ### Server

  use GenServer

  def init(
        {%{block_finality_margin: finality_margin, service_name: service_name}, get_ethereum_events_callback,
         process_events_callback}
      ) do
    # TODO: initialize state with the last ethereum block we have seen events from
    {:ok, parent_start_height} = Eth.get_root_deployment_height()

    schedule_get_events()

    _ = Logger.info(fn -> "Starting EthereumEventListener" end)

    {:ok,
     %Core{
       current_block_height: parent_start_height,
       service_name: service_name,
       block_finality_margin: finality_margin,
       get_ethereum_events_callback: get_ethereum_events_callback,
       process_events_callback: process_events_callback
     }}
  end

  def handle_info(:get_events, state) do
    {:ok, next_sync_height} = RootChainCoordinator.synced(state.current_block_height, state.service_name)

    new_state =
      case Core.next_events_block_height(state, next_sync_height) do
        {:get_events, eth_block_height_with_events, state} ->
          {:ok, events} =
            state.get_ethereum_events_callback.(eth_block_height_with_events, eth_block_height_with_events)

          :ok = state.process_events_callback.(events)

          _ =
            Logger.debug(fn ->
              "get_events called successfully with '#{inspect(Enum.count(events))}' events processed."
            end)

          state

        {:dont_get_events, state} ->
          _ = Logger.debug(fn -> "No blocks with event" end)
          state
      end

    schedule_get_events()
    {:noreply, new_state}
  end

  defp schedule_get_events do
    Process.send_after(self(), :get_events, 0)
  end
end
