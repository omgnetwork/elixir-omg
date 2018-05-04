defmodule OmiseGO.API.EthereumEventListener do
  @moduledoc """
  Periodically fetches events made on dynamically changing block range
  on parent chain and feeds them to state.
  For code simplicity it listens for events in blocks with a configured finality margin.
  """

  alias OmiseGO.Eth
  alias OmiseGO.API.EthereumEventListener.Core

  ### Client

  def start_link(config, get_events_callback, process_events_callback) do
    GenServer.start_link(__MODULE__, {config, get_events_callback, process_events_callback})
  end

  ### Server

  use GenServer

  def init({
    %{
      block_finality_margin: finality_margin,
      max_blocks_in_fetch: max_blocks,
      get_events_interval: get_events_interval
    },
    get_ethereum_events_callback,
    process_events_callback}) do

    #TODO: initialize state with the last ethereum block we have seen events from

    with {:ok, parent_start} <- Eth.get_root_deployment_height() do
      schedule_get_events(0)
      {:ok,
       %Core{
         last_event_block: parent_start,
         block_finality_margin: finality_margin,
         max_blocks_in_fetch: max_blocks,
         get_events_interval: get_events_interval,
         get_ethereum_events_callback: get_ethereum_events_callback,
         process_events_callback: process_events_callback
       }
      }
    end
  end

  def handle_info(:get_events, state) do
    with {:ok, eth_block_height} <- Eth.get_ethereum_height(),
         {:ok, new_state, next_get_events_interval, eth_block_from, eth_block_to} <-
           Core.get_events_block_range(state, eth_block_height),
         {:ok, events} <- state.get_ethereum_events_callback.(eth_block_from, eth_block_to),
         :ok <- state.process_events_callback.(events) do
      schedule_get_events(next_get_events_interval)
      {:noreply, new_state}
    else
      {:no_blocks_with_event, state, next_get_events_interval} ->
        schedule_get_events(next_get_events_interval)
        {:noreply, state}
      _ -> {:stop, :failed_to_get_ethereum_events, state}
    end
  end

  defp schedule_get_events(interval) do
    Process.send_after(self(), :get_events, interval)
  end
end
