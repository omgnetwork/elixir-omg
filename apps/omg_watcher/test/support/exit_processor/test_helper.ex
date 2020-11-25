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

defmodule OMG.Watcher.ExitProcessor.TestHelper do
  @moduledoc """
  Common utilities to manipulate the `ExitProcessor`
  """

  import ExUnit.Assertions

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor.Core

  require Utxo

  # default exit_id used when starting exits using `start_se_from` and `start_ife_from`
  @exit_id 9876

  def start_se_from(%Core{} = processor, tx, exiting_pos, opts \\ []) do
    {event, status} = se_event_status(tx, exiting_pos, opts)
    {processor, _} = Core.new_exits(processor, [event], [status])
    processor
  end

  def se_event_status(tx, exiting_pos, opts \\ []) do
    Utxo.position(_, _, oindex) = exiting_pos
    txbytes = Transaction.raw_txbytes(tx)
    enc_pos = Utxo.Position.encode(exiting_pos)
    owner = tx |> Transaction.get_outputs() |> Enum.at(oindex) |> Map.get(:owner)
    eth_height = Keyword.get(opts, :eth_height, 2)
    exit_id = Keyword.get(opts, :exit_id, @exit_id)
    root_chain_txhash = <<1::256>>
    block_timestamp = :os.system_time(:second)
    scheduled_finalization_time = block_timestamp + 100

    event = %{
      utxo_pos: enc_pos,
      output_tx: txbytes,
      owner: owner,
      eth_height: eth_height,
      exit_id: exit_id,
      root_chain_txhash: root_chain_txhash,
      block_timestamp: block_timestamp,
      scheduled_finalization_time: scheduled_finalization_time
    }

    exitable = not Keyword.get(opts, :inactive, false)
    # those should be unused so setting to `nil`
    fake_output_id = enc_pos
    amount = nil
    bond_size = nil

    status = Keyword.get(opts, :status) || {exitable, enc_pos, fake_output_id, owner, amount, bond_size}

    {event, status}
  end

  def start_ife_from(%Core{} = processor, tx, opts \\ []) do
    exit_id = Keyword.get(opts, :exit_id, @exit_id)
    status = Keyword.get(opts, :status, active_ife_status())
    status = if status == :inactive, do: inactive_ife_status(), else: status

    {processor, _} = Core.new_in_flight_exits(processor, [ife_event(tx, opts)], [{status, exit_id}])

    processor
  end

  # See `OMG.Eth.RootChain.get_in_flight_exits_structs/2` for reference of where this comes from
  # `nil`s are unused portions of the returns data from the contract
  def active_ife_status(), do: {nil, 1, nil, nil, nil, nil, nil}
  def inactive_ife_status(), do: {nil, 0, nil, nil, nil, nil, nil}

  def piggyback_ife_from(%Core{} = processor, tx_hash, output_index, piggyback_type) do
    {processor, _} =
      Core.new_piggybacks(processor, [
        %{
          tx_hash: tx_hash,
          output_index: output_index,
          omg_data: %{piggyback_type: piggyback_type}
        }
      ])

    processor
  end

  def ife_event(tx, opts \\ []) do
    sigs = Keyword.get(opts, :sigs) || sigs(tx)
    input_utxos_pos = Transaction.get_inputs(tx) |> Enum.map(&Utxo.Position.encode/1)

    input_txs = Keyword.get(opts, :input_txs) || List.duplicate("input_tx", length(input_utxos_pos))

    eth_height = Keyword.get(opts, :eth_height, 2)

    %{
      in_flight_tx: Transaction.raw_txbytes(tx),
      input_txs: input_txs,
      input_utxos_pos: input_utxos_pos,
      in_flight_tx_sigs: sigs,
      eth_height: eth_height
    }
  end

  def ife_response(tx, position),
    do: %{tx_hash: Transaction.raw_txhash(tx), challenge_position: Utxo.Position.encode(position)}

  def ife_challenge(tx, comp, opts \\ []) do
    competitor_position = Keyword.get(opts, :competitor_position)

    competitor_position =
      if competitor_position,
        do: Utxo.Position.encode(competitor_position),
        else: not_included_competitor_pos()

    %{
      tx_hash: Transaction.raw_txhash(tx),
      competitor_position: competitor_position,
      call_data: %{
        competing_tx: txbytes(comp),
        competing_tx_input_index: Keyword.get(opts, :competing_tx_input_index, 0),
        competing_tx_sig: Keyword.get(opts, :competing_tx_sig, sig(comp))
      }
    }
  end

  def txbytes(tx), do: Transaction.raw_txbytes(tx)
  def sigs(tx), do: tx.signed_tx.sigs
  def sig(tx, idx \\ 0), do: tx |> sigs() |> Enum.at(idx)

  def assert_proof_sound(proof_bytes) do
    # NOTE: checking of actual proof working up to the contract integration test
    assert is_binary(proof_bytes)
    # hash size * merkle tree depth
    assert byte_size(proof_bytes) == 32 * 16
  end

  def assert_events(events, expected_events) do
    assert MapSet.new(events) == MapSet.new(expected_events)
  end

  def check_validity_filtered(request, processor, opts) do
    exclude_events = Keyword.get(opts, :exclude, [])
    only_events = Keyword.get(opts, :only, [])

    {result, events} = Core.check_validity(request, processor)

    any? = fn filtering_events, event ->
      Enum.any?(filtering_events, fn filtering_event -> event.__struct__ == filtering_event end)
    end

    filtered_events =
      events
      |> Enum.filter(fn event ->
        Enum.empty?(exclude_events) or not any?.(exclude_events, event)
      end)
      |> Enum.filter(fn event ->
        Enum.empty?(only_events) or any?.(only_events, event)
      end)

    {result, filtered_events}
  end

  defp not_included_competitor_pos() do
    <<long::256>> =
      List.duplicate(<<255::8>>, 32)
      |> Enum.reduce(fn val, acc -> val <> acc end)

    long
  end
end
