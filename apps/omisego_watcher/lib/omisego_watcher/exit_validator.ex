# Copyright 2017 OmiseGO Pte Ltd
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

defmodule OmiseGOWatcher.ExitValidator do
  @moduledoc """
  Detects exits for spent utxos and notifies challenger
  """

  alias OmiseGOWatcher.ExitValidator.Core

  def start_link(last_exit_block_height_callback, utxo_exists_callback, synced_block_margin, update_key) do
    GenServer.start_link(
      __MODULE__,
      {last_exit_block_height_callback, utxo_exists_callback, synced_block_margin, update_key}
    )
  end

  def sync_eth_height(synced_eth_height) do
    GenServer.call(__MODULE__, {:validate_exits, synced_eth_height})
  end

  use GenServer

  def init({last_exit_block_height_callback, utxo_exists_callback, synced_block_margin, update_key}) do
    {:ok, last_exit_block_height} = last_exit_block_height_callback.()

    {:ok,
     %Core{
       last_exit_block_height: last_exit_block_height,
       update_key: update_key,
       margin_on_synced_block: synced_block_margin,
       utxo_exists_callback: utxo_exists_callback
     }}
  end

  def handle_call({:validate_exits, synced_eth_block_height}, _from, state) do
    with {block_from, block_to, state, db_updates} <- Core.get_exits_block_range(state, synced_eth_block_height),
         utxo_exits <- OmiseGO.Eth.get_exits(block_from, block_to),
         :ok <- validate_exits(utxo_exits, state) do
      :ok = OmiseGO.DB.multi_update(db_updates)
      {:noreply, state}
    else
      :empty_range -> {:noreply, state}
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
end
