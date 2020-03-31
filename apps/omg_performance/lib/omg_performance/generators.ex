# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.Performance.Generators do
  @moduledoc """
  Provides helper functions to generate bundles of various useful entities for performance tests
  """
  require OMG.Utxo

  alias OMG.Eth.Configuration
  alias OMG.Eth.RootChain

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.HttpRPC.Client
  alias Support.DevHelper

  @generate_user_timeout 600_000

  @doc """
  Creates addresses with private keys and funds them with given `initial_funds_wei` on geth.

  Options:
    - :faucet - the address to send the test ETH from, assumed to be unlocked and have the necessary funds
    - :initial_funds_wei - the amount of test ETH that will be granted to every generated user
  """
  @spec generate_users(non_neg_integer, [Keyword.t()]) :: [OMG.TestHelper.entity()]
  def generate_users(size, opts \\ []) do
    1..size
    |> Task.async_stream(fn _ -> generate_user(opts) end, timeout: @generate_user_timeout)
    |> Enum.map(fn {:ok, result} -> result end)
  end

  @doc """
  Streams encoded output position from all transactions from a given blocks.
  Blocks are streamed form child chain rpc if not provided.

  Options:
    - :use_blocks - if not nil, will use this as the stream of blocks, otherwise streams from child chain rpc
    - :take - if not nil, will limit to this many results
  """
  @spec stream_utxo_positions(keyword()) :: [non_neg_integer()]
  def stream_utxo_positions(opts \\ []) do
    utxo_positions =
      opts[:use_blocks]
      |> if(do: opts[:use_blocks], else: stream_blocks())
      |> Stream.flat_map(&to_utxo_position_list(&1, opts))

    if opts[:take], do: Enum.take(utxo_positions, opts[:take]), else: utxo_positions
  end

  @spec stream_blocks() :: [OMG.Block.t()]
  defp stream_blocks() do
    child_chain_url = OMG.Watcher.Configuration.child_chain_url()
    interval = Configuration.child_block_interval()

    Stream.map(
      Stream.iterate(1, &(&1 + 1)),
      &get_block!(&1 * interval, child_chain_url)
    )
  end

  defp generate_user(opts) do
    user = OMG.TestHelper.generate_entity()
    {:ok, _user} = DevHelper.import_unlock_fund(user, opts)
    user
  end

  defp get_block!(blknum, child_chain_url) do
    {block_hash, _} = RootChain.blocks(blknum)
    {:ok, block} = poll_get_block(block_hash, child_chain_url)
    block
  end

  defp to_utxo_position_list(block, opts) do
    block.transactions
    |> Stream.with_index()
    |> Stream.flat_map(fn {tx, index} ->
      transaction_to_output_positions(tx, block.number, index, opts)
    end)
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

  defp poll_get_block(block_hash, child_chain_url) do
    poll_get_block(block_hash, child_chain_url, 50)
  end

  defp poll_get_block(block_hash, child_chain_url, 0), do: Client.get_block(block_hash, child_chain_url)

  defp poll_get_block(block_hash, child_chain_url, retry) do
    case Client.get_block(block_hash, child_chain_url) do
      {:ok, _block} = result ->
        result

      _ ->
        Process.sleep(10)
        poll_get_block(block_hash, child_chain_url, retry - 1)
    end
  end
end
