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

defmodule OMG.Watcher.Integration.TestHelper do
  @moduledoc """
  Common helper functions that are useful when integration-testing the watcher
  """

  alias OMG.API.Crypto
  alias OMG.API.State
  alias OMG.API.Utxo
  alias OMG.Eth

  require Utxo
  import OMG.Watcher.TestHelper

  def get_exit_data(blknum, txindex, oindex) do
    utxo_pos = Utxo.Position.encode({:utxo_position, blknum, txindex, oindex})

    data = success?("utxo.get_exit_data", %{utxo_pos: utxo_pos})

    decode16(data, ["txbytes", "proof", "sigs"])
  end

  def get_utxos(%{addr: address}) do
    {:ok, address_encode} = Crypto.encode_address(address)

    utxos = success?("utxo.get", %{address: address_encode})

    utxos
  end

  def get_exit_challenge(blknum, txindex, oindex) do
    utxo_pos = Utxo.position(blknum, txindex, oindex) |> Utxo.Position.encode()

    data = success?("utxo.get_challenge_data", %{utxo_pos: utxo_pos})

    decode16(data, ["txbytes", "sig"])
  end

  def get_in_flight_exit(transaction) do
    exit_data = success?("transaction.get_in_flight_exit_data", %{transaction: transaction})

    decode16(exit_data, ["in_flight_tx", "in_flight_tx_sigs", "input_txs", "input_txs_inclusion_proofs"])
  end

  def wait_for_block_getter_down do
    :ok = wait_for_process(Process.whereis(OMG.Watcher.BlockGetter))
  end

  def wait_for_block_fetch(block_nr, timeout) do
    fn ->
      Eth.WaitFor.repeat_until_ok(wait_for_block(block_nr))
    end
    |> Task.async()
    |> Task.await(timeout)

    # write to db seems to be async and wait_for_block_fetch would return too early, so sleep
    # leverage `block` events if they get implemented
    Process.sleep(100)
  end

  defp wait_for_block(block_nr) do
    # TODO query to State used in tests instead of an event system, remove when event system is here
    fn ->
      if State.get_status() |> elem(0) <= block_nr,
        do: :repeat,
        else: {:ok, block_nr}
    end
  end

  @doc """
  We need to wait on both a margin of eth blocks and exit processing
  """
  def wait_for_exit_processing(exit_eth_height, timeout \\ 5_000) do
    exit_processor_validation = Application.fetch_env!(:omg_watcher, :exit_processor_validation_interval_ms)
    exit_finality = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    Eth.DevHelpers.wait_for_root_chain_block(exit_eth_height + exit_finality, timeout)
    Process.sleep(exit_processor_validation * 2)
  end
end
