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

defmodule OMG.WatcherInfo.Factory do
  @moduledoc """
  Test data factory for OMG.WatcherInfo.

  Use this module to build structs or insert data into WatcherInfo's database.

  ## Usage

  Import this factory into your test module with `import OMG.WatcherInfo.Factory`.

  Then, use [`build/1`](https://hexdocs.pm/ex_machina/ExMachina.html#c:build/1)
  to build a struct without inserting them to the database, or
  [`build/2`](https://hexdocs.pm/ex_machina/ExMachina.html#c:build/2) to override default data.

  Or use [`insert/1`](https://hexdocs.pm/ex_machina/ExMachina.html#c:insert/1) to build and
  insert the struct to database or [`build/2`](https://hexdocs.pm/ex_machina/ExMachina.html#c:build/2)
  to insert with overrides.

  See all available APIs at https://hexdocs.pm/ex_machina/ExMachina.html.

  ## Example

      defmodule MyTest do
        use ExUnit.Case

        import OMG.WatcherInfo.Factory

        test ... do
          # Returns %OMG.WatcherInfo.DB.Block{blknum: ..., hash: ...}
          build(:block)

          # Returns %OMG.WatcherInfo.DB.Block{blknum: 1234, hash: ...}
          build(:block, blknum: 1234)

          # Inserts and returns %OMG.WatcherInfo.DB.Block{blknum: ..., hash: ...}
          insert(:block)

          # Inserts and returns %OMG.WatcherInfo.DB.Block{blknum: 1234, hash: ...}
          insert(:block, blknum: 1234)
        end
      end
  """
  use ExMachina.Ecto, repo: OMG.WatcherInfo.DB.Repo

  alias OMG.WatcherInfo.DB

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @doc """
  Block factory.

  Generates a block in an incremental blknum of 1000, 2000, 3000, etc.
  """
  def block_factory() do
    %DB.Block{
      blknum: sequence(:block_blknum, fn seq -> seq * 1000 end),
      hash: sequence(:block_hash, fn seq -> <<seq::256>> end),
      eth_height: sequence(:block_eth_height, fn seq -> seq end),
      timestamp: sequence(:block_timestamp, fn seq -> seq * 1_000_000 end)
    }
  end

  @doc """
  Transaction factory.

  Generates a transaction without any transaction output and no associated block.

  To generate a transaction with closest data to production, consider associating the transaction
  to a block and generating transaction outputs associated with this transaction.
  """
  def transaction_factory() do
    %DB.Transaction{
      txhash: sequence(:block_hash, fn seq -> <<seq::256>> end),
      txindex: 0,
      txbytes: :crypto.strong_rand_bytes(8),
      sent_at: DateTime.utc_now(),
      metadata: :crypto.strong_rand_bytes(8),
      block: nil,
      inputs: [],
      outputs: []
    }
  end

  @doc """
  Txoutput factory.

  Generates a txoutput. The txindex, oindex and spending_tx_oindex are defaulted to 0.
  These two values need to be overridden depending on the transaction you aim to build.
  """
  def txoutput_factory() do
    owner = OMG.TestHelper.generate_entity()

    %DB.TxOutput{
      blknum: insert(:block).blknum,
      txindex: 0,
      oindex: 0,
      owner: owner.addr,
      amount: 100,
      currency: @eth,
      proof: :crypto.strong_rand_bytes(8),
      spending_tx_oindex: 0,
      child_chain_utxohash: :crypto.strong_rand_bytes(8),
      creating_transaction: insert(:transaction),
      spending_transaction: nil
    }
  end
end
