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

  alias OMG.Utxo
  require Utxo

  alias OMG.Eth.Encoding

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @doc """
  Block factory.

  Generates a block in an incremental blknum of 1000, 2000, 3000, etc.
  """
  def block_factory() do
    %DB.Block{
      blknum: sequence(:block_blknum, fn seq -> seq * 1000 end),
      hash: insecure_random_bytes(32),
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
      txhash: sequence(:transaction_hash, fn seq -> <<seq::256>> end),
      txindex: 0,
      txbytes: insecure_random_bytes(32),
      sent_at: DateTime.utc_now(),
      metadata: insecure_random_bytes(32),
      block: nil,
      inputs: [],
      outputs: []
    }
  end

  @doc """
  Txoutput factory.

  Generates a txoutput. A new block and transaction are generated per each txoutput built.
  Therefore, if you are overriding some values, also consider its relation to other values. E.g:

    - To override `blknum`, also consider overriding `txindex`.
    - To override `creating_transaction`, also consider overriding `txindex` and `oindex`.
    - To override `spending_transaction`, also consider overriding `spending_tx_oindex`
  """
  def txoutput_factory(attrs \\ %{}) do
    block = attrs[:block] || build(:block)

    # need to check key existence because value may be nil which is valid
    creating_transaction =
      case Map.has_key?(attrs, :creating_transaction) do
        true -> attrs[:creating_transaction]
        false -> build(:transaction, block: block)
      end

    ethevents = attrs[:ethevents] || []

    txoutput = %DB.TxOutput{
      blknum: block.blknum,
      txindex: 0,
      oindex: 0,
      owner: insecure_random_bytes(20),
      amount: 100,
      currency: @eth,
      proof: insecure_random_bytes(32),
      spending_tx_oindex: nil,
      creating_transaction: creating_transaction,
      spending_transaction: nil,
      ethevents: ethevents
    }

    child_chain_utxohash =
      DB.TxOutput.generate_child_chain_utxohash(Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex))

    txoutput = Map.put(txoutput, :child_chain_utxohash, child_chain_utxohash)

    merge_attributes(txoutput, attrs)
  end

  @doc """
  EthEvent factory.

  Generates an ethevent. For testing flexibility, an ethevent can be created with 0 txoutputs. Although this does not
  conform to the business logic, this violates no database constraints.

  To associate an ethevent with one or more txoutputs, an array of txoutputs can be passed in via by overriding
  `txoutputs`.

  Most scenarios will have a only a 1-1 relationship between ethevents an txoutputs. However, with an ExitFinalized
  (process exit) scenario, an ethevent may have many txoutputs. A txoutput for every utxo in the exit queue when
  processExits() was called.

  The default event type is `:deposit`, but can be overridden by setting `event_type`.
  """
  def ethevent_factory(attrs \\ nil) do
    event_type = attrs[:event_type] || :deposit
    txoutputs = attrs[:txoutputs] || []

    ethevent = %DB.EthEvent{
      root_chain_txhash: insecure_random_bytes(32),
      # within a log there may be 0 or more ethereum events, this is the index of the
      # event within the log
      log_index: 0,
      event_type: event_type,
      txoutputs: txoutputs
    }

    root_chain_txhash_event =
      DB.EthEvent.generate_root_chain_txhash_event(ethevent.root_chain_txhash, ethevent.log_index)

    ethevent = Map.put(ethevent, :root_chain_txhash_event, root_chain_txhash_event)

    merge_attributes(ethevent, attrs)
  end

  ##
  ## non-schema based test data helpers
  ##
  def deposits_params(n) do
    Enum.map(0..(n - 1), fn _ -> deposit_params() end)
  end

  def deposit_params(attrs \\ nil) do
    block = attrs[:block] || insert(:block)

    params_for(:ethevent)
    |> Map.drop([:root_chain_txhash_event, :txoutputs])
    |> Map.merge(%{blknum: block.blknum, currency: <<0>>, owner: insecure_random_bytes(20), amount: 1})
  end

  def exits_params(ethevents) do
    Enum.map(ethevents, fn ethevent -> exit_params(ethevent) end)
  end

  def exit_params(ethevent) do
    [txoutput | _] = ethevent.txoutputs

    %{
      root_chain_txhash: Encoding.to_hex(ethevent.root_chain_txhash),
      log_index: ethevent.log_index,
      call_data: %{utxo_pos: Utxo.Position.encode(Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex))}
    }
  end

  # Generates a certain length of random bytes. Uniqueness not guaranteed so it's not recommended for identifiers.
  defp insecure_random_bytes(num_bytes) when num_bytes >= 0 and num_bytes <= 255 do
    0..255 |> Enum.shuffle() |> Enum.take(num_bytes) |> :erlang.list_to_binary()
  end
end
