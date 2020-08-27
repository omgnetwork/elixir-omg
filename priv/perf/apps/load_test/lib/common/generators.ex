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

defmodule LoadTest.Common.Generators do
  @moduledoc """
  Provides helper functions to generate bundles of various useful entities for performance tests
  """

  alias ExPlasma.Encoding
  alias LoadTest.ChildChain.Transaction
  alias LoadTest.Ethereum
  alias LoadTest.Ethereum.Account

  @generate_user_timeout 600_000

  @doc """
  Creates addresses with private keys and funds them with given `initial_funds_wei` on geth.

  Options:
    - :faucet - the address to send the test ETH from, assumed to be unlocked and have the necessary funds
    - :initial_funds_wei - the amount of test ETH that will be granted to every generated user
  """
  @spec generate_users(non_neg_integer) :: [map()]
  def generate_users(size) do
    1..size
    |> Task.async_stream(fn _ -> generate_user() end, timeout: @generate_user_timeout)
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

  @spec stream_blocks() :: [map()]
  defp stream_blocks() do
    child_chain_url = Application.fetch_env!(:load_test, :child_chain_url)
    interval = Application.fetch_env!(:load_test, :child_block_interval)

    Stream.map(
      Stream.iterate(1, &(&1 + 1)),
      &get_block!(&1 * interval, child_chain_url)
    )
  end

  defp generate_user() do
    {:ok, user} = Account.new()

    {:ok, address} = Ethereum.create_account_from_secret(user.priv, "pass")
    {:ok, _} = Ethereum.unlock_account(address, "pass")
    {:ok, _} = Ethereum.fund_address_from_default_faucet(user, [])

    user
  end

  defp get_block!(blknum, child_chain_url) do
    {block_hash, _} = Ethereum.block_hash(blknum)
    {:ok, block} = poll_get_block(block_hash, child_chain_url)
    block
  end

  defp to_utxo_position_list(block, opts) do
    block["transactions"]
    |> Stream.with_index()
    |> Stream.flat_map(fn {tx, index} ->
      transaction_to_output_positions(tx, block["blknum"], index, opts)
    end)
  end

  defp transaction_to_output_positions(tx, blknum, txindex, opts) do
    filtered_address = opts[:owned_by]

    tx
    |> Transaction.recover()
    |> get_outputs()
    |> Enum.filter(&(is_nil(filtered_address) || &1.owner == filtered_address))
    |> Enum.with_index()
    |> Enum.map(fn {_, oindex} ->
      ExPlasma.Utxo.pos(%{blknum: blknum, txindex: txindex, oindex: oindex})
    end)
  end

  defp get_outputs(transaction) do
    transaction.raw_tx.outputs
  end

  defp poll_get_block(block_hash, child_chain_url) do
    poll_get_block(block_hash, child_chain_url, 50)
  end

  defp poll_get_block(block_hash, child_chain_url, retry) do
    case ChildChainAPI.Api.Block.block_get(
           LoadTest.Connection.ChildChain.client(),
           %ChildChainAPI.Model.GetBlockBodySchema{hash: Encoding.to_hex(block_hash)}
         ) do
      {:ok, block_response} ->
        {:ok, Jason.decode!(block_response.body)["data"]}

      _ ->
        Process.sleep(10)
        poll_get_block(block_hash, child_chain_url, retry - 1)
    end
  end
end
