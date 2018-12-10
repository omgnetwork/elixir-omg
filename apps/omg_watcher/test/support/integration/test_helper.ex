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

    %{"result" => "success", "data" => data} = rpc_call("utxo.get_exit_data", %{utxo_pos: utxo_pos})

    decode16(data, ["txbytes", "proof", "sigs"])
  end

  def get_utxos(%{addr: address}) do
    {:ok, address_encode} = Crypto.encode_address(address)

    %{"result" => "success", "data" => utxos} = rpc_call("utxo.get", %{address: address_encode})

    utxos
  end

  def get_exit_challenge(blknum, txindex, oindex) do
    utxo_pos = Utxo.position(blknum, txindex, oindex) |> Utxo.Position.encode()

    %{"result" => "success", "data" => data} = rpc_call("utxo.get_challenge_data", %{utxo_pos: utxo_pos})

    decode16(data, ["txbytes", "proof", "sigs"])
  end

  def wait_for_current_block_fetch(timeout) do
    {:ok, current_child_block} = Eth.RootChain.get_current_child_block()
    wait_for_block_fetch(current_child_block, timeout)
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
end
