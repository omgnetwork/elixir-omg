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

defmodule OMG.WatcherInfo.DB.EthEventTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.Fixtures

  alias OMG.Crypto
  alias OMG.Utils.Paginator
  alias OMG.Utxo
  alias OMG.Utxo.Position
  alias OMG.WatcherInfo.DB

  import OMG.WatcherInfo.Factory

  require Utxo

  @eth OMG.Eth.zero_address()
  @default_paginator %Paginator{
    data: [],
    data_paging: %{
      limit: 10,
      page: 1
    }
  }

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "insert deposits: creates deposit event and utxo" do
    expected_root_chain_txnhash = Crypto.hash(<<1::256>>)
    expected_log_index = 0
    expected_event_type = :deposit
    expected_eth_height = 1

    expected_blknum = 10_000
    expected_txindex = 0
    expected_oindex = 0
    expected_owner = <<1::160>>
    expected_currency = @eth
    expected_amount = 1

    root_chain_txhash_event =
      DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txnhash, expected_log_index)

    expected_child_chain_utxohash =
      DB.EthEvent.generate_child_chain_utxohash(Utxo.position(expected_blknum, expected_txindex, expected_oindex))

    assert :ok =
             DB.EthEvent.insert_deposits!([
               %{
                 root_chain_txhash: expected_root_chain_txnhash,
                 log_index: expected_log_index,
                 blknum: expected_blknum,
                 owner: expected_owner,
                 eth_height: expected_eth_height,
                 currency: expected_currency,
                 amount: expected_amount
               }
             ])

    event = DB.EthEvent.get(root_chain_txhash_event)

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txnhash,
             log_index: ^expected_log_index,
             event_type: ^expected_event_type,
             eth_height: ^expected_eth_height
           } = event

    # check ethevent side of relationship
    assert length(event.txoutputs) == 1

    assert [
             %DB.TxOutput{
               blknum: ^expected_blknum,
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
             }
             | _tail
           ] = event.txoutputs

    # check txoutput side of relationship
    txoutput = DB.TxOutput.get_by_position(Utxo.position(expected_blknum, expected_txindex, expected_oindex))

    assert %DB.TxOutput{
             blknum: ^expected_blknum,
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

    assert [
             %DB.EthEvent{
               root_chain_txhash: ^expected_root_chain_txnhash,
               log_index: ^expected_log_index,
               event_type: ^expected_event_type,
               eth_height: ^expected_eth_height
             }
             | _tail
           ] = txoutput.ethevents
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice]
  test "insert deposits: creates deposits and retrieves them by hash", %{alice: alice} do
    expected_event_type = :deposit
    expected_owner = alice.addr
    expected_currency = @eth
    expected_log_index = 0
    expected_amount = 1
    expected_eth_height = 1

    expected_root_chain_txhash_1 = Crypto.hash(<<2::256>>)

    expected_root_chain_txhash_event_1 =
      DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_1, expected_log_index)

    expected_blknum_1 = 20_000

    expected_root_chain_txhash_2 = Crypto.hash(<<3::256>>)

    expected_root_chain_txhash_event_2 =
      DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_2, expected_log_index)

    expected_blknum_2 = 30_000

    expected_root_chain_txhash_3 = Crypto.hash(<<4::256>>)

    expected_root_chain_txhash_event_3 =
      DB.EthEvent.generate_root_chain_txhash_event(expected_root_chain_txhash_3, expected_log_index)

    expected_blknum_3 = 40_000

    assert :ok =
             DB.EthEvent.insert_deposits!([
               %{
                 root_chain_txhash: expected_root_chain_txhash_1,
                 log_index: expected_log_index,
                 blknum: expected_blknum_1,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount,
                 eth_height: expected_eth_height
               },
               %{
                 root_chain_txhash: expected_root_chain_txhash_2,
                 log_index: expected_log_index,
                 blknum: expected_blknum_2,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount,
                 eth_height: expected_eth_height
               },
               %{
                 root_chain_txhash: expected_root_chain_txhash_3,
                 log_index: expected_log_index,
                 blknum: expected_blknum_3,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount,
                 eth_height: expected_eth_height
               }
             ])

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_1,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_1,
             eth_height: expected_eth_height
           } = DB.EthEvent.get(expected_root_chain_txhash_event_1)

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_2,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_2,
             eth_height: expected_eth_height
           } = DB.EthEvent.get(expected_root_chain_txhash_event_2)

    assert %DB.EthEvent{
             root_chain_txhash: ^expected_root_chain_txhash_3,
             event_type: ^expected_event_type,
             root_chain_txhash_event: ^expected_root_chain_txhash_event_3,
             eth_height: expected_eth_height
           } = DB.EthEvent.get(expected_root_chain_txhash_event_3)

    %{data: alice_utxos} = DB.TxOutput.get_utxos(address: alice.addr)

    assert [^expected_root_chain_txhash_1, ^expected_root_chain_txhash_2, ^expected_root_chain_txhash_3] =
             Enum.map(alice_utxos, fn txoutput ->
               [head | _tail] = txoutput.ethevents
               head.root_chain_txhash
             end)
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "insert exits: creates exit event and marks utxo as spent" do
    expected_owner = <<1::160>>
    expected_log_index = 0
    expected_amount = 1
    expected_currency = @eth

    expected_blknum = 50_000
    expected_txindex = 0
    expected_oindex = 0

    expected_utxo_encoded_position = Position.encode(Utxo.position(expected_blknum, expected_txindex, expected_oindex))

    expected_deposit_root_chain_txhash = Crypto.hash(<<5::256>>)
    expected_exit_root_chain_txhash = Crypto.hash(<<6::256>>)

    expected_deposit_eth_height = 1
    expected_exit_eth_height = 2

    assert :ok =
             DB.EthEvent.insert_deposits!([
               %{
                 root_chain_txhash: expected_deposit_root_chain_txhash,
                 log_index: expected_log_index,
                 blknum: expected_blknum,
                 owner: expected_owner,
                 currency: expected_currency,
                 amount: expected_amount,
                 eth_height: expected_deposit_eth_height
               }
             ])

    %{data: utxos} = DB.TxOutput.get_utxos(address: expected_owner)
    assert length(utxos) == 1

    assert :ok =
             DB.EthEvent.insert_exits!([
               %{
                 call_data: %{utxo_pos: expected_utxo_encoded_position},
                 root_chain_txhash: expected_exit_root_chain_txhash,
                 log_index: expected_log_index,
                 eth_height: expected_exit_eth_height
               }
             ])

    %{data: utxos_after_exit} = DB.TxOutput.get_utxos(address: expected_owner)
    assert Enum.empty?(utxos_after_exit)
  end

  @tag fixtures: [:alice, :initial_blocks]
  test "Writes of deposits and exits are idempotent", %{alice: alice} do
    # try to insert again existing deposit (from initial_blocks)
    assert :ok =
             DB.EthEvent.insert_deposits!([
               %{
                 root_chain_txhash: Crypto.hash(<<1000::256>>),
                 eth_height: 1,
                 log_index: 0,
                 owner: alice.addr,
                 currency: @eth,
                 amount: 333,
                 blknum: 1
               }
             ])

    exits = [
      %{
        root_chain_txhash: Crypto.hash(<<1000::256>>),
        log_index: 1,
        call_data: %{utxo_pos: Utxo.Position.encode(Utxo.position(1, 0, 0))},
        eth_height: 2
      },
      %{
        root_chain_txhash: Crypto.hash(<<1000::256>>),
        log_index: 1,
        call_data: %{utxo_pos: Utxo.Position.encode(Utxo.position(1, 0, 0))},
        eth_height: 2
      }
    ]

    assert :ok = DB.EthEvent.insert_exits!(exits)
  end

  @tag fixtures: [:alice, :initial_blocks]
  test "Can spend multiple outputs with single start_ife event", %{alice: alice} do
    expected_log_index = 0
    expected_eth_height = 0
    expected_eth_txhash = Crypto.hash(<<6::256>>)
    expected_event_type = :in_flight_exit

    %{data: utxos} = DB.TxOutput.get_utxos(address: alice.addr)

    [
      %DB.TxOutput{blknum: blknum1, txindex: txindex1, oindex: oindex1},
      %DB.TxOutput{blknum: blknum2, txindex: txindex2, oindex: oindex2} | _
    ] = utxos

    utxo_pos1 = Utxo.position(blknum1, txindex1, oindex1)
    utxo_pos2 = Utxo.position(blknum2, txindex2, oindex2)

    exits = [
      %{
        root_chain_txhash: expected_eth_txhash,
        log_index: expected_log_index,
        eth_height: expected_eth_height,
        call_data: %{utxo_pos: Utxo.Position.encode(utxo_pos1)}
      },
      %{
        root_chain_txhash: expected_eth_txhash,
        log_index: expected_log_index,
        eth_height: expected_eth_height,
        call_data: %{utxo_pos: Utxo.Position.encode(utxo_pos2)}
      }
    ]

    assert :ok = DB.EthEvent.insert_exits!(exits, expected_event_type)

    txo1 = DB.TxOutput.get_by_position(utxo_pos1)
    assert txo1 != nil

    assert [
             %DB.EthEvent{
               log_index: ^expected_log_index,
               root_chain_txhash: ^expected_eth_txhash,
               event_type: ^expected_event_type
             }
           ] = txo1.ethevents

    txo2 = DB.TxOutput.get_by_position(utxo_pos2)
    assert txo2 != nil

    assert [
             %DB.EthEvent{
               log_index: ^expected_log_index,
               root_chain_txhash: ^expected_eth_txhash,
               event_type: ^expected_event_type
             }
           ] = txo2.ethevents
  end

  @tag fixtures: [:alice, :initial_blocks]
  test "Can spend ife piggybacked output", %{alice: alice} do
    expected_log_index1 = 0
    expected_log_index2 = 1
    expected_eth_height1 = 0
    expected_eth_height2 = 1
    expected_eth_txhash1 = Crypto.hash(<<6::256>>)
    expected_eth_txhash2 = Crypto.hash(<<7::256>>)
    expected_event_type = :in_flight_exit

    %{data: utxos} = DB.TxOutput.get_utxos(address: alice.addr)

    [
      %DB.TxOutput{creating_txhash: txhash1, oindex: oindex1},
      %DB.TxOutput{creating_txhash: txhash2, oindex: oindex2}
    ] =
      utxos
      |> Enum.drop(1)
      |> Enum.take(2)

    exits = [
      %{
        root_chain_txhash: expected_eth_txhash1,
        log_index: expected_log_index1,
        eth_height: expected_eth_height1,
        call_data: %{txhash: txhash1, oindex: oindex1}
      },
      %{
        root_chain_txhash: expected_eth_txhash2,
        log_index: expected_log_index2,
        eth_height: expected_eth_height2,
        call_data: %{txhash: txhash2, oindex: oindex2}
      }
    ]

    assert :ok = DB.EthEvent.insert_exits!(exits, expected_event_type)

    assert_txoutput_spent_by_event(
      txhash1,
      oindex1,
      expected_log_index1,
      expected_eth_txhash1,
      expected_eth_height1,
      expected_event_type
    )

    assert_txoutput_spent_by_event(
      txhash2,
      oindex2,
      expected_log_index2,
      expected_eth_txhash2,
      expected_eth_height2,
      expected_event_type
    )
  end

  defp assert_txoutput_spent_by_event(txhash, oindex, log_index, eth_txhash, eth_height, event_type) do
    txo = DB.TxOutput.get_by_output_id(txhash, oindex)

    assert txo != nil

    assert [
             %DB.EthEvent{
               log_index: ^log_index,
               root_chain_txhash: ^eth_txhash,
               eth_height: ^eth_height,
               event_type: ^event_type
             }
           ] = txo.ethevents
  end

  describe "get_events" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "filters ethevents by address if given an address argument" do
      owner_1 = <<1::160>>
      owner_2 = <<2::160>>

      deposit_output_1 = build(:txoutput, %{owner: owner_1})
      deposit_output_2 = build(:txoutput, %{owner: owner_2})

      _ = insert(:ethevent, event_type: :deposit, txoutputs: [deposit_output_1])
      _ = insert(:ethevent, event_type: :deposit, txoutputs: [deposit_output_2])

      %{data: [event_1]} = DB.EthEvent.get_events(@default_paginator, nil, owner_1)
      %{data: [event_2]} = DB.EthEvent.get_events(@default_paginator, nil, owner_2)

      assert event_1 |> Map.get(:txoutputs) |> Enum.at(0) |> Map.get(:owner) == owner_1
      assert event_2 |> Map.get(:txoutputs) |> Enum.at(0) |> Map.get(:owner) == owner_2
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "includes ethevents with multiple outputs if at least one is owned by the given address" do
      owner_1 = <<1::160>>
      owner_2 = <<2::160>>

      txo_1 = build(:txoutput, %{owner: owner_1})
      txo_2 = build(:txoutput, %{owner: owner_2})
      txo_3 = build(:txoutput, %{owner: owner_2})

      inserted_event = insert(:ethevent, txoutputs: [txo_1, txo_2])
      _ = insert(:ethevent, txoutputs: [txo_3])

      %{data: [returned_event]} = DB.EthEvent.get_events(@default_paginator, nil, owner_1)

      assert inserted_event.root_chain_txhash == returned_event.root_chain_txhash
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "filters Ethereum events by type if given an event_type argument" do
      _ = insert(:ethevent, event_type: :deposit)
      _ = insert(:ethevent, event_type: :standard_exit)
      _ = insert(:ethevent, event_type: :standard_exit)

      %{data: [deposit]} = DB.EthEvent.get_events(@default_paginator, :deposit, nil)

      %{data: [se_1, se_2]} = DB.EthEvent.get_events(@default_paginator, :standard_exit, nil)

      assert Map.get(deposit, :event_type) == :deposit
      assert Map.get(se_1, :event_type) == :standard_exit
      assert Map.get(se_2, :event_type) == :standard_exit
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns Ethereum events sorted by descending eth_height" do
      _ = insert(:ethevent, eth_height: 1)
      _ = insert(:ethevent, eth_height: 3)
      _ = insert(:ethevent, eth_height: 2)

      results = DB.EthEvent.get_events(@default_paginator, nil, nil)

      assert results.data |> Enum.at(0) |> Map.get(:eth_height) == 3
      assert results.data |> Enum.at(1) |> Map.get(:eth_height) == 2
      assert results.data |> Enum.at(2) |> Map.get(:eth_height) == 1
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "pagination - correctly paginates responses" do
      _ = insert(:ethevent)
      _ = insert(:ethevent)
      _ = insert(:ethevent)

      paginator_1 = %Paginator{
        data: [],
        data_paging: %{
          limit: 2,
          page: 1
        }
      }

      paginator_2 = %Paginator{
        data: [],
        data_paging: %{
          limit: 2,
          page: 2
        }
      }

      %{data: data_page_1} = DB.EthEvent.get_events(paginator_1, nil, nil)
      %{data: data_page_2} = DB.EthEvent.get_events(paginator_2, nil, nil)

      assert length(data_page_1) == 2
      assert length(data_page_2) == 1
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "pagination - returns empty array if given limit 0" do
      _ = insert(:ethevent)
      _ = insert(:ethevent)
      _ = insert(:ethevent)

      paginator = %Paginator{
        data: [],
        data_paging: %{
          limit: 0,
          page: 1
        }
      }

      %{data: data} = DB.EthEvent.get_events(paginator, nil, nil)

      assert Enum.empty?(data)
    end
  end
end
