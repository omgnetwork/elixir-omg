# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Performance.ByzantineEvents.Generators do
  @moduledoc """
  Module to generate users,
  and stream of transaction, utxo position, block using data from child chain
  """

  alias OMG.Eth
  alias OMG.Eth.RootChain
  alias OMG.State.Transaction
  alias OMG.Utils.HttpRPC.Client
  alias OMG.Utxo

  require Utxo

  @child_chain_url Application.get_env(:byzantine_events, :child_chain_url)

  def generate_users(size, opts \\ [initial_funds: trunc(:math.pow(10, 18))]) do
    async_generate_user = fn _ -> Task.async(fn -> generate_user(opts) end) end

    1..size
    |> Enum.chunk_every(10)
    |> Enum.map(fn chunk ->
      Enum.map(chunk, async_generate_user)
      |> Enum.map(&Task.await(&1, :infinity))
    end)
    |> List.flatten()
  end

  def generate_user(opts) do
    user = OMG.TestHelper.generate_entity()
    {:ok, _user} = Eth.DevHelpers.import_unlock_fund(user, opts)
    user
  end

  def stream_txs(blocks \\ block_stream()) do
    blocks
    |> Stream.map(& &1.transactions)
    |> Stream.concat()
  end

  def stream_utxo_positions(blocks \\ block_stream()) do
    blocks
    |> Stream.map(&to_utxo_position_list(&1))
    |> Stream.concat()
  end

  def block_stream(child_chain_url \\ @child_chain_url) do
    {:ok, interval} = RootChain.get_child_block_interval()

    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(&get_block!(&1 * interval, child_chain_url))
  end

  def random_block(child_chain_url \\ @child_chain_url) do
    {:ok, interval} = RootChain.get_child_block_interval()
    {:ok, mined_block} = RootChain.get_mined_child_block()
    # interval <= blknum <= mined_block
    blknum = :rand.uniform(div(mined_block, interval)) * interval
    get_block!(blknum, child_chain_url)
  end

  defp get_block!(blknum, child_chain_url) do
    {:ok, block} =
      Eth.WaitFor.repeat_until_ok(fn ->
        with {:ok, {block_hash, _timestamp}} <- RootChain.get_child_chain(blknum) do
          Client.get_block(block_hash, child_chain_url)
        else
          _ -> :repeat
        end
      end)

    block
  end

  defp to_utxo_position_list(block) do
    Stream.with_index(block.transactions)
    |> Stream.map(fn {tx, index} ->
      recover_tx = Transaction.Recovered.recover_from!(tx)

      Transaction.get_outputs(recover_tx)
      |> Enum.with_index()
      |> Enum.map(fn {_, oindex} ->
        Utxo.position(block.number, index, oindex)
        |> Utxo.Position.encode()
      end)
    end)
    |> Stream.concat()
  end
end
