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
  Provides helper functions to generate spenders for perftest,
  Streams transactions, utxo positions and blocks using data from Watcher.
  """

  alias OMG.Eth.RootChain
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.HttpRPC.Client
  alias Support.DevHelper
  alias Support.WaitFor

  require Utxo

  @child_chain_url Application.get_env(:omg_watcher, :child_chain_url)

  @doc """
  Creates addresses with private keys and funds them with given `initial_funds` on geth.
  """
  @spec generate_users(non_neg_integer, [Keyword.t()]) :: [OMG.TestHelper.entity()]
  def generate_users(size, opts \\ [initial_funds: trunc(:math.pow(10, 18))]) do
    async_generate_user = fn _ -> Task.async(fn -> generate_user(opts) end) end

    async_generate_users_chunk = fn chunk ->
      chunk
      |> Enum.map(async_generate_user)
      |> Enum.map(&Task.await(&1, :infinity))
    end

    1..size
    |> Enum.chunk_every(10)
    |> Enum.map(async_generate_users_chunk)
    |> List.flatten()
  end

  @doc """
  Streams blocks from child chain rpc starting from the first block.
  """
  @spec stream_blocks(child_chain_url: binary()) :: [OMG.Block.t()]
  def stream_blocks(child_chain_url \\ @child_chain_url) do
    {:ok, interval} = RootChain.get_child_block_interval()

    Stream.map(
      Stream.iterate(1, &(&1 + 1)),
      &get_block!(&1 * interval, child_chain_url)
    )
  end

  @doc """
  Streams rlp-encoded transactions from a given blocks.
  Blocks are streamed form child chain rpc if not provided.
  """
  @spec stream_transactions([OMG.Block.t()]) :: [binary()]
  def stream_transactions(blocks \\ nil) do
    blocks
    |> if(do: blocks, else: stream_blocks())
    |> Stream.map(& &1.transactions)
    |> Stream.concat()
  end

  @doc """
  Streams encoded output position from all transactions from a given blocks.
  Blocks are streamed form child chain rpc if not provided.
  """
  @spec stream_utxo_positions([OMG.Block.t()]) :: [non_neg_integer()]
  def stream_utxo_positions(blocks \\ nil, opts \\ []) do
    blocks
    |> if(do: blocks, else: stream_blocks())
    |> Stream.map(&to_utxo_position_list(&1, opts))
    |> Stream.concat()
  end

  @doc """
  Gets a mined block at random. Block is fetch from child chain rpc.
  """
  @spec random_block(child_chain_url: binary()) :: OMG.Block.t()
  def random_block(child_chain_url \\ @child_chain_url) do
    {:ok, interval} = RootChain.get_child_block_interval()
    {:ok, mined_block} = RootChain.get_mined_child_block()
    # interval <= blknum <= mined_block
    blknum = :rand.uniform(div(mined_block, interval)) * interval
    get_block!(blknum, child_chain_url)
  end

  defp generate_user(opts) do
    user = OMG.TestHelper.generate_entity()
    {:ok, _user} = DevHelper.import_unlock_fund(user, opts)
    user
  end

  # FIXME: why the repeat & waitfor?
  defp get_block!(blknum, child_chain_url) do
    {:ok, block} =
      WaitFor.repeat_until_ok(fn ->
        with {:ok, {block_hash, _timestamp}} <- RootChain.get_child_chain(blknum) do
          Client.get_block(block_hash, child_chain_url)
        else
          _ -> :repeat
        end
      end)

    block
  end

  defp to_utxo_position_list(block, opts) do
    block.transactions
    |> Stream.with_index()
    |> Stream.map(fn {tx, index} ->
      transaction_to_output_positions(tx, block.number, index, opts)
    end)
    |> Stream.concat()
  end

  defp transaction_to_output_positions(tx, blknum, txindex, opts) do
    filtered_address = opts[:owned_by]

    tx
    |> Transaction.Recovered.recover_from!()
    |> Transaction.get_outputs()
    |> Enum.filter(&(is_nil(filtered_address) || &1.owner == filtered_address))
    |> Enum.with_index()
    |> Enum.map(fn {_, oindex} ->
      utxo_pos = Utxo.position(blknum, txindex, oindex)
      Utxo.Position.encode(utxo_pos)
    end)
  end
end
