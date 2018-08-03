defmodule OmiseGOWatcher.ExitValidator do
  @moduledoc """
  Detects exits for spent utxos and notifies challenger
  """

  alias OmiseGO.API.RootChainCoordinator
  alias OmiseGOWatcher.ExitValidator.Core

  def start_link(last_exit_block_height_callback, utxo_exists_callback, synced_block_margin, update_key, service_name) do
    GenServer.start_link(
      __MODULE__,
      {last_exit_block_height_callback, utxo_exists_callback, synced_block_margin, update_key, service_name}
    )
  end

  use GenServer

  def init({last_exit_block_height_callback, utxo_exists_callback, synced_block_margin, update_key, service_name}) do
    # gets last ethereum block height that we fetched exits from
    {:ok, last_exit_block_height} = last_exit_block_height_callback.()

    :ok = RootChainCoordinator.set_service_height(last_exit_block_height, service_name)
    schedule_validate_exits()

    {:ok,
     %Core{
       last_exit_block_height: last_exit_block_height,
       synced_height: last_exit_block_height,
       update_key: update_key,
       margin_on_synced_block: synced_block_margin,
       utxo_exists_callback: utxo_exists_callback,
       service_name: service_name
     }}
  end

  def handle_info(
        :validate_exits,
        %Core{last_exit_block_height: last_exit_block_height} = state
      ) do
    case RootChainCoordinator.get_height() do
      :no_sync ->
        {:noreply, state}

      {:sync, next_sync_height} ->
        case Core.next_events_block_height(state, next_sync_height) do
          {block_height_to_get_exits_from, state, db_updates} ->
            {:ok, utxo_exits} = OmiseGO.Eth.get_exits(last_exit_block_height, block_height_to_get_exits_from)
            :ok = validate_exits(utxo_exits, state)
            :ok = OmiseGO.DB.multi_update(db_updates)
            :ok = RootChainCoordinator.set_service_height(next_sync_height, state.service_name)

            {:noreply, state}

          :empty_range ->
            {:noreply, state}
        end
    end
  end

  defp validate_exits(utxo_exits, state) do
    for utxo_exit <- utxo_exits do
      :ok = validate_exit(utxo_exit, state)
    end

    :ok
  end

  defp validate_exit(%{blknum: blknum, txindex: txindex, oindex: oindex} = utxo_exit, %Core{
         utxo_exists_callback: utxo_exists_callback
       }) do
    with :utxo_does_not_exist <- OmiseGO.API.State.utxo_exists(%{blknum: blknum, txindex: txindex, oindex: oindex}),
         :challenged <- OmiseGOWatcher.Challenger.challenge(utxo_exit) do
      :ok
    else
      :utxo_exists -> utxo_exists_callback.(utxo_exit)
    end
  end

  defp schedule_validate_exits(interval \\ 200) do
    :timer.send_interval(interval, self(), :validate_exits)
  end
end
