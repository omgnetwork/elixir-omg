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

defmodule OMG.Watcher.ExitProcessor.PersistenceTest do
  @moduledoc """
  Test focused on the persistence bits of `OMG.Watcher.ExitProcessor.Core`.

  The aim of this test is to ensure, that whatever state the processor ends up being in will be revived from the DB
  """

  use ExUnitFixtures
  use OMG.DB.RocksDBCase, async: true

  alias OMG.DB.Models.PaymentExitInfo
  alias OMG.DevCrypto
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor.Core

  require Utxo

  import OMG.Watcher.ExitProcessor.TestHelper

  @default_min_exit_period_seconds 120
  @default_child_block_interval 1000
  @eth OMG.Eth.zero_address()

  @utxo_pos1 Utxo.position(1, 0, 0)
  @utxo_pos2 Utxo.position(1_000, 0, 1)

  @zero_exit_id 0
  @non_zero_exit_id 1
  @zero_sig <<0::520>>

  setup %{db_pid: db_pid} do
    :ok = OMG.DB.initiation_multiupdate(db_pid)

    alice = OMG.TestHelper.generate_entity()
    carol = OMG.TestHelper.generate_entity()
    {:ok, processor_empty} = Core.init([], [], [], @default_min_exit_period_seconds, @default_child_block_interval)

    transactions = [
      Transaction.Payment.new([{1, 0, 0}, {1, 2, 1}], [{alice.addr, @eth, 1}, {carol.addr, @eth, 2}]),
      Transaction.Payment.new([{2, 1, 0}, {2, 2, 1}], [{alice.addr, @eth, 1}, {carol.addr, @eth, 2}])
    ]

    [txbytes1, txbytes2] = transactions |> Enum.map(&Transaction.raw_txbytes/1)

    exits =
      {[
         %{
           owner: alice.addr,
           eth_height: 2,
           exit_id: 1,
           call_data: %{utxo_pos: Utxo.Position.encode(@utxo_pos1), output_tx: txbytes1},
           root_chain_txhash: <<1::256>>,
           block_timestamp: 1,
           scheduled_finalization_time: 2
         },
         %{
           owner: alice.addr,
           eth_height: 4,
           exit_id: 2,
           call_data: %{utxo_pos: Utxo.Position.encode(@utxo_pos2), output_tx: txbytes2},
           root_chain_txhash: <<2::256>>,
           block_timestamp: 3,
           scheduled_finalization_time: 4
         }
       ],
       [
         {true, Utxo.Position.encode(@utxo_pos1), Utxo.Position.encode(@utxo_pos1), alice.addr, 10, 0},
         {false, Utxo.Position.encode(@utxo_pos2), Utxo.Position.encode(@utxo_pos2), alice.addr, 10, 0}
       ]}

    {:ok, %{alice: alice, carol: carol, processor_empty: processor_empty, transactions: transactions, exits: exits}}
  end

  test "persist finalizations with mixed validities",
       %{processor_empty: processor, db_pid: db_pid, exits: {exit_events, statuses}} do
    processor
    |> persist_new_exits(exit_events, statuses, db_pid)
    |> persist_finalize_exits({[@utxo_pos1], [@utxo_pos2]}, db_pid)
  end

  test "persist finalizations with all valid",
       %{processor_empty: processor, db_pid: db_pid, exits: {exit_events, statuses}} do
    processor
    |> persist_new_exits(exit_events, statuses, db_pid)
    |> persist_finalize_exits({[@utxo_pos1, @utxo_pos2], []}, db_pid)
  end

  test "persist finalizations with all invalid",
       %{processor_empty: processor, db_pid: db_pid, exits: {exit_events, statuses}} do
    processor
    |> persist_new_exits(exit_events, statuses, db_pid)
    |> persist_finalize_exits({[], [@utxo_pos1, @utxo_pos2]}, db_pid)
  end

  test "persist challenges",
       %{processor_empty: processor, db_pid: db_pid, exits: {exit_events, statuses}} do
    processor
    |> persist_new_exits(exit_events, statuses, db_pid)
    |> persist_challenge_exits([@utxo_pos1], db_pid)
  end

  test "persist multiple challenges",
       %{processor_empty: processor, db_pid: db_pid, exits: {exit_events, statuses}} do
    processor
    |> persist_new_exits(exit_events, statuses, db_pid)
    |> persist_challenge_exits([@utxo_pos2, @utxo_pos1], db_pid)
  end

  test "persist started ifes regardless of status",
       %{processor_empty: processor, alice: alice, carol: carol, db_pid: db_pid} do
    txs = [
      Transaction.Payment.new([{1, 0, 0}, {1, 2, 1}], [{alice.addr, @eth, 1}]),
      Transaction.Payment.new([{2, 1, 0}, {2, 2, 1}], [{alice.addr, @eth, 1}, {carol.addr, @eth, 2}])
    ]

    contract_statuses = [{active_ife_status(), @non_zero_exit_id}, {inactive_ife_status(), @zero_exit_id}]

    processor
    |> persist_new_ifes(txs, [[alice.priv], [alice.priv, carol.priv]], contract_statuses, db_pid)
  end

  test "persist new challenges, responses and piggybacks",
       %{processor_empty: processor, alice: alice, db_pid: db_pid} do
    tx = Transaction.Payment.new([{2, 1, 0}], [{alice.addr, @eth, 1}, {alice.addr, @eth, 2}])
    hash = Transaction.raw_txhash(tx)
    competing_tx = Transaction.Payment.new([{2, 1, 0}, {1, 0, 0}], [{alice.addr, @eth, 2}, {alice.addr, @eth, 1}])

    challenge = %{
      tx_hash: hash,
      competitor_position: Utxo.Position.encode(@utxo_pos2),
      call_data: %{
        competing_tx: Transaction.raw_txbytes(competing_tx),
        competing_tx_input_index: 0,
        competing_tx_sig: @zero_sig
      }
    }

    piggybacks1 = [
      %{tx_hash: hash, output_index: 0, omg_data: %{piggyback_type: :input}},
      %{tx_hash: hash, output_index: 0, omg_data: %{piggyback_type: :output}}
    ]

    piggybacks2 = [%{tx_hash: hash, output_index: 1, omg_data: %{piggyback_type: :output}}]

    processor
    |> persist_new_ifes([tx], [[alice.priv]], db_pid)
    |> persist_new_piggybacks(piggybacks1, db_pid)
    |> persist_new_piggybacks(piggybacks2, db_pid)
    |> persist_new_ife_challenges([challenge], db_pid)
    |> persist_challenge_piggybacks(piggybacks2, db_pid)
    |> persist_challenge_piggybacks(piggybacks1, db_pid)
    |> persist_respond_to_in_flight_exits_challenges([ife_response(tx, @utxo_pos1)], db_pid)
  end

  test "persist ife finalizations",
       %{processor_empty: processor, alice: alice, db_pid: db_pid} do
    tx = Transaction.Payment.new([{2, 1, 0}], [{alice.addr, @eth, 1}, {alice.addr, @eth, 2}])
    hash = Transaction.raw_txhash(tx)

    piggybacks1 = [
      %{tx_hash: hash, output_index: 0, omg_data: %{piggyback_type: :input}},
      %{tx_hash: hash, output_index: 0, omg_data: %{piggyback_type: :output}}
    ]

    piggybacks2 = [%{tx_hash: hash, output_index: 1, omg_data: %{piggyback_type: :output}}]

    processor
    |> persist_new_ifes([tx], [[alice.priv]], db_pid)
    |> persist_new_piggybacks(piggybacks1, db_pid)
    |> persist_new_piggybacks(piggybacks2, db_pid)
    |> persist_finalize_ifes(
      [%{in_flight_exit_id: @non_zero_exit_id, output_index: 0, omg_data: %{piggyback_type: :input}}],
      db_pid
    )
    |> persist_finalize_ifes(
      [
        %{in_flight_exit_id: @non_zero_exit_id, output_index: 0, omg_data: %{piggyback_type: :output}},
        %{in_flight_exit_id: @non_zero_exit_id, output_index: 1, omg_data: %{piggyback_type: :output}}
      ],
      db_pid
    )
  end

  # mimics `&OMG.Watcher.ExitProcessor.init/1`
  defp state_from(db_pid) do
    {:ok, db_exits} = PaymentExitInfo.all_exit_infos(db_pid)
    {:ok, db_ifes} = PaymentExitInfo.in_flight_exits_info(db_pid)
    {:ok, db_competitors} = OMG.DB.competitors_info(db_pid)

    {:ok, state} =
      Core.init(db_exits, db_ifes, db_competitors, @default_min_exit_period_seconds, @default_child_block_interval)

    state
  end

  defp persist_common(processor, db_updates, db_pid) do
    assert :ok = OMG.DB.multi_update(db_updates, db_pid)
    assert processor == state_from(db_pid)
    processor
  end

  defp persist_new_exits(processor, exit_events, contract_statuses, db_pid) do
    {processor, db_updates} = Core.new_exits(processor, exit_events, contract_statuses)
    persist_common(processor, db_updates, db_pid)
  end

  defp persist_finalize_exits(processor, validities, db_pid) do
    {processor, db_updates} = Core.finalize_exits(processor, validities)
    persist_common(processor, db_updates, db_pid)
  end

  defp persist_challenge_exits(processor, utxo_positions, db_pid) do
    {processor, db_updates} =
      Core.challenge_exits(processor, utxo_positions |> Enum.map(&%{utxo_pos: Utxo.Position.encode(&1)}))

    persist_common(processor, db_updates, db_pid)
  end

  defp persist_new_ifes(processor, txs, priv_keys, statuses \\ nil, db_pid) do
    in_flight_exit_events =
      txs
      |> Enum.zip(priv_keys)
      |> Enum.map(fn {tx, keys} -> {tx, DevCrypto.sign(tx, keys)} end)
      |> Enum.map(fn {tx, signed_tx} -> ife_event(tx, sigs: signed_tx.sigs) end)

    statuses = statuses || List.duplicate({active_ife_status(), @non_zero_exit_id}, length(in_flight_exit_events))
    {processor, db_updates} = Core.new_in_flight_exits(processor, in_flight_exit_events, statuses)
    persist_common(processor, db_updates, db_pid)
  end

  defp persist_new_piggybacks(processor, piggybacks, db_pid) do
    {processor, db_updates} = Core.new_piggybacks(processor, piggybacks)
    persist_common(processor, db_updates, db_pid)
  end

  defp persist_new_ife_challenges(processor, challenges, db_pid) do
    {processor, db_updates} = Core.new_ife_challenges(processor, challenges)
    persist_common(processor, db_updates, db_pid)
  end

  defp persist_respond_to_in_flight_exits_challenges(processor, challenges, db_pid) do
    {processor, db_updates} = Core.respond_to_in_flight_exits_challenges(processor, challenges)
    persist_common(processor, db_updates, db_pid)
  end

  defp persist_challenge_piggybacks(processor, piggybacks, db_pid) do
    {processor, db_updates} = Core.challenge_piggybacks(processor, piggybacks)
    persist_common(processor, db_updates, db_pid)
  end

  defp persist_finalize_ifes(processor, finalizations, db_pid) do
    {:ok, processor, db_updates} = Core.finalize_in_flight_exits(processor, finalizations, %{})
    persist_common(processor, db_updates, db_pid)
  end
end
