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

defmodule OMG.Performance.Generators do
  @moduledoc """
  Provides helper functions to generate bundles of various useful entities for performance tests
  """

  alias OMG.Eth.RootChain
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.HttpRPC.Client
  alias Support.DevHelper

  require Utxo

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
  Streams blocks from child chain rpc starting from the first block.
  """
  @spec stream_blocks() :: [OMG.Block.t()]
  def stream_blocks() do
    child_chain_url = Application.fetch_env!(:omg_watcher, :child_chain_url)
    {:ok, interval} = RootChain.get_child_block_interval()

    Stream.map(
      Stream.iterate(1, &(&1 + 1)),
      &get_block!(&1 * interval, child_chain_url)
    )
  end

  @doc """
  Streams rlp-encoded transactions from a given blocks.
  Blocks are streamed form child chain rpc if not provided.

  Options:
    - :use_blocks - if not nil, will use this as the stream of blocks, otherwise streams from child chain rpc
    - :no_deposit_spends - if true, will limit only to transactions that do ont spend deposits (see function with the
      same name for explanation)
    - :sent_by - if not nil, will limit to txs sent
    - :take - if not nil, will limit to this many results
  """
  @spec stream_transactions([OMG.Block.t()]) :: [binary()]
  def stream_transactions(opts \\ []) do
    transactions =
      opts[:use_blocks]
      |> if(do: opts[:use_blocks], else: stream_blocks())
      |> Stream.flat_map(& &1.transactions)

    transactions =
      if(opts[:no_deposit_spends],
        do: Stream.filter(transactions, &no_deposit_spends?/1),
        else: transactions
      )

    transactions =
      if(opts[:sent_by],
        do: Stream.filter(transactions, &is_sent_by?(&1, opts[:sent_by])),
        else: transactions
      )

    if opts[:take], do: Enum.take(transactions, opts[:take]), else: transactions
  end

  # NOTE: whoops, we cannot open IFEs from included txs spending deposits. When fixed, remove this filter
  #       https://github.com/omisego/elixir-omg/issues/1128
  defp no_deposit_spends?(txbytes) do
    txbytes
    |> Transaction.Signed.decode!()
    |> Transaction.get_inputs()
    |> Enum.any?(&Utxo.Position.is_deposit?/1)
    |> Kernel.not()
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

  @doc """
  Gets a mined block at random. Block is fetch from child chain rpc.
  """
  @spec random_block() :: OMG.Block.t()
  def random_block() do
    child_chain_url = Application.fetch_env!(:omg_watcher, :child_chain_url)
    {:ok, interval} = RootChain.get_child_block_interval()
    {:ok, mined_block} = RootChain.get_mined_child_block()
    # interval <= blknum <= mined_block
    blknum = :rand.uniform(div(mined_block, interval)) * interval
    get_block!(blknum, child_chain_url)
  end

  defp is_sent_by?(txbytes, address) do
    %Transaction.Recovered{witnesses: witnesses} = tx = Transaction.Recovered.recover_from!(txbytes)
    # runtime assertion if we're not using this for non-Payment txs. The next line might not work if witnesses are
    # not addresses
    %Transaction.Payment{} = tx.signed_tx.raw_tx

    witnesses
    |> Map.values()
    |> Enum.uniq()
    |> Kernel.==([address])
  end

  defp generate_user(opts) do
    user = OMG.TestHelper.generate_entity()
    {:ok, _user} = DevHelper.import_unlock_fund(user, opts)
    user
  end

  defp get_block!(blknum, child_chain_url) do
    {:ok, {block_hash, _timestamp}} = RootChain.get_child_chain(blknum)
    {:ok, block} = Client.get_block(block_hash, child_chain_url)
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
end
