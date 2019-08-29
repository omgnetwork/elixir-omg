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

defmodule OMG.Watcher.DB.EthEventTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  alias OMG.Crypto
  alias OMG.Utxo
  alias OMG.Utxo.Position
  alias OMG.Watcher.DB

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "insert deposits: creates deposit event and utxo" do
    expected_root_chain_txnhash = Crypto.hash(<<1::256>>)
    expected_log_index = 0
    expected_event_type = :deposit

    root_chain_txhash_event = DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txnhash, expected_log_index)
    expected_child_chain_utxohash = DB.EthEvent.generate_child_chain_utxohash(Utxo.position(1, 0, 0))

    expected_blk_num = 1
    expected_txindex = 0
    expected_oindex = 0
    expected_owner = <<1::160>>
    expected_currency = @eth
    expected_amount = 1

    assert :ok =
       DB.EthEvent.insert_deposits!([%{
        root_chain_txhash: expected_root_chain_txnhash,
        log_index: expected_log_index,
        blknum: expected_blk_num,
        owner: expected_owner,
        currency: expected_currency,
        amount: expected_amount
      }])

    event = DB.EthEvent.get(root_chain_txhash_event)

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txnhash,
             log_index: ^expected_log_index,
             event_type: ^expected_event_type
           } = event

    # check ethevent side of relationship
    assert length(event.txoutputs) == 1
    assert [%DB.TxOutput{
              blknum: ^expected_blk_num,
              txindex: ^expected_txindex,
              oindex: ^expected_oindex,
              owner: ^expected_owner,
              amount: ^expected_amount,
              currency: ^expected_currency,

              creating_txhash: nil,
              spending_txhash: nil,

              spending_tx_oindex: nil,
              proof: nil,

              child_chain_utxohash: ^expected_child_chain_utxohash
            } | _tail ] = event.txoutputs

    # check txoutput side of relationship
    txoutput = DB.TxOutput.get_by_position(Utxo.position(expected_blk_num, expected_txindex, expected_oindex))

    assert %DB.TxOutput{
             blknum: ^expected_blk_num,
             txindex: ^expected_txindex,
             oindex: ^expected_oindex,
             owner: ^expected_owner,
             amount: ^expected_amount,
             currency: ^expected_currency,

             creating_txhash: nil,
             spending_txhash: nil,

             spending_tx_oindex: nil,
             proof: nil,

             child_chain_utxohash: ^expected_child_chain_utxohash
           } = txoutput

    assert length(txoutput.ethevents) == 1
    assert [%DB.EthEvent{
              root_chain_txhash: ^expected_root_chain_txnhash,
              log_index: ^expected_log_index,
              event_type: ^expected_event_type
            } | _tail ] = txoutput.ethevents
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice]
  test "insert deposits: creates deposits and retrieves them by hash", %{alice: alice} do
    expected_event_type = :deposit
    expected_owner = alice.addr
    expected_currency = @eth
    expected_log_index = 0
    expected_amount = 1

    expected_root_chain_txhash_1 = Crypto.hash(<<2::256>>)
    expected_root_chain_txhash_event_1 = DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_1, expected_log_index)
    expected_blk_num_1 = 1

    expected_root_chain_txhash_2 = Crypto.hash(<<3::256>>)
    expected_root_chain_txhash_event_2 = DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_2, expected_log_index)
    expected_blk_num_2 = 1000

    expected_root_chain_txhash_3 = Crypto.hash(<<4::256>>)
    expected_root_chain_txhash_event_3 = DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_3, expected_log_index)
    expected_blk_num_3 = 2000

    assert :ok =
      DB.EthEvent.insert_deposits!([
        %{root_chain_txhash: expected_root_chain_txhash_1, log_index: expected_log_index, blknum: expected_blk_num_1,
          owner: expected_owner, currency: expected_currency, amount: expected_amount
        },
        %{root_chain_txhash: expected_root_chain_txhash_2, log_index: expected_log_index, blknum: expected_blk_num_2,
          owner: expected_owner, currency: expected_currency, amount: expected_amount
        },
        %{root_chain_txhash: expected_root_chain_txhash_3, log_index: expected_log_index, blknum: expected_blk_num_3,
          owner: expected_owner, currency: expected_currency, amount: expected_amount
        },
      ])

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_1,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_1}
           = DB.EthEvent.get(expected_root_chain_txhash_event_1)

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_2,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_2}
           = DB.EthEvent.get(expected_root_chain_txhash_event_2)

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_3,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_3}
           = DB.EthEvent.get(expected_root_chain_txhash_event_3)

    assert [^expected_root_chain_txhash_1, ^expected_root_chain_txhash_2, ^expected_root_chain_txhash_3] =
             DB.TxOutput.get_utxos(alice.addr) |> Enum.map(fn txoutput ->
               [head | _tail] = txoutput.ethevents
               head.root_chain_txhash
             end)
  end

  #  @tag fixtures: [:initial_blocks]
  @tag fixtures: [:phoenix_ecto_sandbox]
  test "insert exits: creates exit event and marks utxo as spent" do

#    bobs_deposit_pos = Utxo.position(2, 0, 0)
#    bobs_deposit_exit_hash = DB.EthEvent.generate_unique_key(bobs_deposit_pos, :exit)
#
#    alices_utxo_pos = Utxo.position(3000, 1, 1)
#    alices_utxo_exit_hash = DB.EthEvent.generate_unique_key(alices_utxo_pos, :exit)
#
#    to_insert = prepare_to_insert([bobs_deposit_pos, alices_utxo_pos])
#    :ok = DB.EthEvent.insert_exits!(to_insert)
#
#    assert %DB.EthEvent{blknum: 2, txindex: 0, event_type: :exit, hash: ^bobs_deposit_exit_hash} =
#             DB.Repo.get(DB.EthEvent, bobs_deposit_exit_hash)
#
#    assert %DB.EthEvent{blknum: 3000, txindex: 1, event_type: :exit, hash: ^alices_utxo_exit_hash} =
#             DB.Repo.get(DB.EthEvent, alices_utxo_exit_hash)
#
#    assert %DB.TxOutput{amount: 100, spending_tx_oindex: nil, spending_exit: ^bobs_deposit_exit_hash} =
#             DB.TxOutput.get_by_position(bobs_deposit_pos)
#
#    assert %DB.TxOutput{amount: 50, spending_tx_oindex: nil, spending_exit: ^alices_utxo_exit_hash} =
#             DB.TxOutput.get_by_position(alices_utxo_pos)



    expected_owner = <<1::160>>
    expected_log_index = 0
    expected_amount = 1
    expected_currency = @eth

    expected_blk_num = 3000
    expected_txindex = 0
    expected_oindex = 0

    expected_utxo_encoded_position = Position.encode(Utxo.position(expected_blk_num, expected_txindex, expected_oindex))

    expected_deposit_root_chain_txhash = Crypto.hash(<<5::256>>)
    expected_exit_root_chain_txhash = Crypto.hash(<<6::256>>)

    assert :ok =
     DB.EthEvent.insert_deposits!([
       %{
         root_chain_txhash: expected_deposit_root_chain_txhash,
         log_index: expected_log_index,
         blknum: expected_blk_num,
         owner: expected_owner,
         currency: expected_currency,
         amount: expected_amount
       }
     ])

    assert :ok = DB.EthEvent.insert_exits!([
      %{
        call_data: %{utxo_pos: expected_utxo_encoded_position},
        root_chain_txhash: expected_exit_root_chain_txhash,
        log_index: expected_log_index
      }
     ])

    assert length(DB.TxOutput.get_utxos(expected_owner)) == 0
  end
#
#  @tag fixtures: [:alice, :initial_blocks]
#  test "Writes of deposits and exits are idempotent", %{alice: alice} do
#    # try to insert again existing deposit (from initial_blocks)
#    assert :ok = DB.EthEvent.insert_deposits!([%{owner: alice.addr, currency: @eth, amount: 333, blknum: 1}])
#
#    to_insert = prepare_to_insert([Utxo.position(1, 0, 0), Utxo.position(1, 0, 0)])
#
#    assert :ok = DB.EthEvent.insert_exits!(to_insert)
#  end
#
#  defp prepare_to_insert(positions),
#    do: Enum.map(positions, &%{call_data: %{utxo_pos: Utxo.Position.encode(&1)}})
end
