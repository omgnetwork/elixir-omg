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

defmodule OMG.Eth.HackNaming do
  @moduledoc """
  Adapt to naming from contracts to elixir-omg.

  I need to do this even though I'm bleeding out of my eyes.
  """
  def deposit(data) do
    # key is naming coming from plasma contracts
    # value is what we use
    contracts_naming = [{"token", :currency}, {"depositor", :owner}, {"blknum", :blknum}, {"amount", :amount}]

    reduce_naming(data, contracts_naming)
  end

  # we always call it output_index, which is kinda weird?
  def piggybacked(data) do
    # key is naming coming from plasma contracts
    # value is what we use
    # in_flight_exit_input_piggybacked -> has "inputIndex" that needs to be converted to :output_index
    # in_flight_exit_output_piggybacked -> has "outputIndex" that needs to be converted to :output_index
    # not a typo, both are output_index.

    case data["inputIndex"] do
      # InFlightExitOutput
      nil ->
        contracts_naming = [
          {"outputIndex", :output_index},
          {"exitTarget", :owner},
          {"txHash", :tx_hash}
        ]

        key = :piggyback_type
        value = :output
        Map.update(reduce_naming(data, contracts_naming), :omg_data, %{key => value}, &Map.put(&1, key, value))

      _ ->
        # InFlightExitInput
        contracts_naming = [
          {"inputIndex", :output_index},
          {"exitTarget", :owner},
          {"txHash", :tx_hash}
        ]

        key = :piggyback_type
        value = :input
        Map.update(reduce_naming(data, contracts_naming), :omg_data, %{key => value}, &Map.put(&1, key, value))
    end
  end

  def block_submitted(data) do
    contracts_naming = [{"blockNumber", :blknum}]
    reduce_naming(data, contracts_naming)
  end

  def exit_finalized(data) do
    contracts_naming = [{"exitId", :exit_id}]
    reduce_naming(data, contracts_naming)
  end

  def in_flight_exit_challenged(data) do
    contracts_naming = [
      {"challenger", :challenger},
      {"challengeTxPosition", :competitor_position},
      {"txHash", :tx_hash}
    ]

    reduce_naming(data, contracts_naming)
  end

  def exit_challenged(data) do
    contracts_naming = [
      {"utxoPos", :utxo_pos}
    ]

    reduce_naming(data, contracts_naming)
  end

  def in_flight_exit_challenge_responded(data) do
    contracts_naming = [
      {"challengeTxPosition", :challenge_position},
      {"challenger", :challenger},
      {"txHash", :tx_hash}
    ]

    reduce_naming(data, contracts_naming)
  end

  def challenge_in_flight_exit_not_canonical(data) do
    contracts_naming = [
      {"competingTx", :competing_tx},
      {"competingTxInclusionProof", :competing_tx_inclusion_proof},
      {"competingTxInputIndex", :competing_tx_input_index},
      {"competingTxPos", :competing_tx_pos},
      {"competingTxWitness", :competing_tx_sig},
      {"inFlightTx", :in_flight_tx},
      {"inFlightTxInputIndex", :in_flight_input_index},
      {"inputTx", :input_tx_bytes},
      {"inputUtxoPos", :input_utxo_pos}
    ]

    # not used and discarded
    Map.delete(reduce_naming(data, contracts_naming), :competing_tx_inclusion_proof)
  end

  def in_flight_exit_blocked(data) do
    # InFlightExitOutputBlocked has outputIndex that's renamed into output_index
    # InFlightExitInputBlocked has inputIndex that's renamed into output_index as well
    case data["inputIndex"] do
      nil ->
        contracts_naming = [
          {"challenger", :challenger},
          {"outputIndex", :output_index},
          {"txHash", :tx_hash}
        ]

        key = :piggyback_type
        value = :output
        Map.update(reduce_naming(data, contracts_naming), :omg_data, %{key => value}, &Map.put(&1, key, value))

      _ ->
        contracts_naming = [
          {"challenger", :challenger},
          {"inputIndex", :output_index},
          {"txHash", :tx_hash}
        ]

        key = :piggyback_type
        value = :input
        Map.update(reduce_naming(data, contracts_naming), :omg_data, %{key => value}, &Map.put(&1, key, value))
    end
  end

  def in_flight_exit_started(data) do
    contracts_naming = [
      {"initiator", :initiator},
      {"txHash", :tx_hash}
    ]

    reduce_naming(data, contracts_naming)
  end

  def exit_started(data) do
    contracts_naming = [
      {"owner", :owner},
      {"exitId", :exit_id}
    ]

    reduce_naming(data, contracts_naming)
  end

  def start_in_flight_exit(data) do
    contracts_naming = [
      {"inFlightTx", :in_flight_tx},
      {"inputTxs", :input_txs},
      {"inputUtxosPos", :input_utxos_pos},
      {"inputTxsInclusionProofs", :input_inclusion_proofs},
      {"inFlightTxWitnesses", :in_flight_tx_sigs}
    ]

    reduce_naming(data, contracts_naming)
  end

  def in_flight_exit_finalized(data) do
    case data["outputIndex"] do
      nil ->
        # InFlightExitInputWithdrawn
        contracts_naming = [{"exitId", :in_flight_exit_id}, {"inputIndex", :output_index}]
        key = :piggyback_type
        value = :input
        Map.update(reduce_naming(data, contracts_naming), :omg_data, %{key => value}, &Map.put(&1, key, value))

      _ ->
        # InFlightExitOutputWithdrawn
        contracts_naming = [{"exitId", :in_flight_exit_id}, {"outputIndex", :output_index}]
        key = :piggyback_type
        value = :output
        Map.update(reduce_naming(data, contracts_naming), :omg_data, %{key => value}, &Map.put(&1, key, value))
    end
  end

  def start_standard_exit(data) do
    contracts_naming = [
      {"outputTxInclusionProof", :output_tx_inclusion_proof},
      {"rlpOutputTx", :output_tx},
      {"utxoPos", :utxo_pos}
    ]

    # not used and discarded
    Map.delete(reduce_naming(data, contracts_naming), :output_tx_inclusion_proof)
  end

  defp reduce_naming(data, contracts_naming) do
    Enum.reduce(contracts_naming, %{}, fn
      {old_name, new_name}, acc ->
        value = Map.get(data, old_name)

        acc
        |> Map.put_new(new_name, value)
        |> Map.delete(old_name)
    end)
  end
end
