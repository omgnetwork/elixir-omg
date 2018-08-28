# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.ExitValidator do
  @moduledoc """
  Detects exits for spent utxos and notifies challenger
  """

  alias OMG.API.RootchainCoordinator
  alias OMG.Watcher.ExitValidator.Core

  @block_offset 1_000_000_000
  @transaction_offset 10_000

  @spec start_link(fun(), fun(), non_neg_integer(), atom(), atom()) :: GenServer.on_start()
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

    :ok = RootchainCoordinator.check_in(last_exit_block_height, service_name)

    height_sync_interval = Application.get_env(:omg_api, :rootchain_height_sync_interval_ms)
    {:ok, _} = schedule_validate_exits(height_sync_interval)

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
    case RootchainCoordinator.get_height() do
      :nosync ->
        {:noreply, state}

      {:sync, next_sync_height} ->
        case Core.next_events_block_height(state, next_sync_height) do
          {block_height_to_get_exits_from, state, db_updates} ->
            {:ok, utxo_exits} = OMG.Eth.get_exits(last_exit_block_height, block_height_to_get_exits_from)
            :ok = validate_exits(utxo_exits, state)
            :ok = OMG.DB.multi_update(db_updates)
            :ok = RootchainCoordinator.check_in(next_sync_height, state.service_name)

            {:noreply, state}

          :empty_range ->
            {:noreply, state}
        end
    end
  end

  defp validate_exits(utxo_exits, state) do
    for utxo_exit <- utxo_exits do
      utxo_position = utxo_exit.utxo_pos
      blknum = div(utxo_position, @block_offset)
      txindex = utxo_position |> rem(@block_offset) |> div(@transaction_offset)
      oindex = utxo_position - blknum * @block_offset - txindex * @transaction_offset
      :ok = validate_exit(%{blknum: blknum, txindex: txindex, oindex: oindex}, state)
    end

    :ok
  end

  defp validate_exit(%{blknum: blknum, txindex: txindex, oindex: oindex} = utxo_exit, %Core{
         utxo_exists_callback: utxo_exists_callback
       }) do
    with :utxo_does_not_exist <- OMG.API.State.utxo_exists(%{blknum: blknum, txindex: txindex, oindex: oindex}),
         :challenged <- OMG.Watcher.Challenger.challenge(utxo_exit) do
      :ok
    else
      :utxo_exists -> utxo_exists_callback.(utxo_exit)
    end
  end

  defp schedule_validate_exits(interval) do
    :timer.send_interval(interval, self(), :validate_exits)
  end
end
