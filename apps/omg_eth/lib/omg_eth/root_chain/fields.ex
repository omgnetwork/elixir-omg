# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Eth.RootChain.Fields do
  @moduledoc """
  Adapt to naming from contracts to elixir-omg.

  I need to do this even though I'm bleeding out of my eyes.
  """
  def rename(data, %ABI.FunctionSelector{function: "DepositCreated"}) do
    # key is naming coming from plasma contracts
    # value is what we use
    contracts_naming = [{"token", :currency}, {"depositor", :owner}, {"blknum", :blknum}, {"amount", :amount}]

    reduce_naming(data, contracts_naming)
  end

  # we always call it output_index, which is kinda weird?
  def rename(data, %ABI.FunctionSelector{function: "InFlightExitInputPiggybacked"}) do
    # key is naming coming from plasma contracts
    # value is what we use
    # in_flight_exit_input_piggybacked -> has "inputIndex" that needs to be converted to :output_index
    # in_flight_exit_output_piggybacked -> has "outputIndex" that needs to be converted to :output_index
    # not a typo, both are output_index.

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

  # we always call it output_index, which is kinda weird?
  def rename(data, %ABI.FunctionSelector{function: "InFlightExitOutputPiggybacked"}) do
    # key is naming coming from plasma contracts
    # value is what we use
    # in_flight_exit_input_piggybacked -> has "inputIndex" that needs to be converted to :output_index
    # in_flight_exit_output_piggybacked -> has "outputIndex" that needs to be converted to :output_index
    # not a typo, both are output_index.
    contracts_naming = [
      {"outputIndex", :output_index},
      {"exitTarget", :owner},
      {"txHash", :tx_hash}
    ]

    key = :piggyback_type
    value = :output
    Map.update(reduce_naming(data, contracts_naming), :omg_data, %{key => value}, &Map.put(&1, key, value))
  end

  def rename(data, %ABI.FunctionSelector{function: "BlockSubmitted"}) do
    contracts_naming = [{"blockNumber", :blknum}]
    reduce_naming(data, contracts_naming)
  end

  def rename(data, %ABI.FunctionSelector{function: "ExitFinalized"}) do
    contracts_naming = [{"exitId", :exit_id}]
    reduce_naming(data, contracts_naming)
  end

  def rename(data, %ABI.FunctionSelector{function: "InFlightExitDeleted"}) do
    contracts_naming = [{"exitId", :exit_id}]
    reduce_naming(data, contracts_naming)
  end

  def rename(data, %ABI.FunctionSelector{function: "InFlightExitChallenged"}) do
    contracts_naming = [
      {"challenger", :challenger},
      {"txHash", :tx_hash},
      {"challengeTxPosition", :competitor_position},
      {"inFlightTxInputIndex", :in_flight_tx_input_index},
      {"challengeTx", :challenge_tx},
      {"challengeTxInputIndex", :challenge_tx_input_index},
      {"challengeTxWitness", :challenge_tx_sig}
    ]

    reduce_naming(data, contracts_naming)
  end

  def rename(data, %ABI.FunctionSelector{function: "ExitChallenged"}) do
    contracts_naming = [
      {"utxoPos", :utxo_pos}
    ]

    reduce_naming(data, contracts_naming)
  end

  def rename(data, %ABI.FunctionSelector{function: "InFlightExitChallengeResponded"}) do
    contracts_naming = [
      {"challengeTxPosition", :challenge_position},
      {"challenger", :challenger},
      {"txHash", :tx_hash}
    ]

    reduce_naming(data, contracts_naming)
  end

  def rename(data, %ABI.FunctionSelector{function: "InFlightExitOutputBlocked"}) do
    # InFlightExitOutputBlocked has outputIndex that's renamed into output_index
    # InFlightExitInputBlocked has inputIndex that's renamed into output_index as well

    contracts_naming = [
      {"challenger", :challenger},
      {"outputIndex", :output_index},
      {"txHash", :tx_hash}
    ]

    key = :piggyback_type
    value = :output
    Map.update(reduce_naming(data, contracts_naming), :omg_data, %{key => value}, &Map.put(&1, key, value))
  end

  def rename(data, %ABI.FunctionSelector{function: "InFlightExitInputBlocked"}) do
    # InFlightExitOutputBlocked has outputIndex that's renamed into output_index
    # InFlightExitInputBlocked has inputIndex that's renamed into output_index as well

    contracts_naming = [
      {"challenger", :challenger},
      {"inputIndex", :output_index},
      {"txHash", :tx_hash}
    ]

    key = :piggyback_type
    value = :input
    Map.update(reduce_naming(data, contracts_naming), :omg_data, %{key => value}, &Map.put(&1, key, value))
  end

  def rename(data, %ABI.FunctionSelector{function: "InFlightExitStarted"}) do
    contracts_naming = [
      {"initiator", :initiator},
      {"txHash", :tx_hash},
      {"inFlightTx", :in_flight_tx},
      {"inputUtxosPos", :input_utxos_pos},
      {"inFlightTxWitnesses", :in_flight_tx_sigs},
      {"inputTxs", :input_txs}
    ]

    reduce_naming(data, contracts_naming)
  end

  def rename(data, %ABI.FunctionSelector{function: "ExitStarted"}) do
    contracts_naming = [
      {"owner", :owner},
      {"exit_id", :exit_id},
      {"utxo_pos", :utxo_pos},
      {"output_tx", :output_tx}
    ]

    reduce_naming(data, contracts_naming)
  end

  def rename(data, %ABI.FunctionSelector{function: "InFlightExitInputWithdrawn"}) do
    # InFlightExitInputWithdrawn
    contracts_naming = [{"exitId", :in_flight_exit_id}, {"inputIndex", :output_index}]
    key = :piggyback_type
    value = :input
    Map.update(reduce_naming(data, contracts_naming), :omg_data, %{key => value}, &Map.put(&1, key, value))
  end

  def rename(data, %ABI.FunctionSelector{function: "InFlightExitOutputWithdrawn"}) do
    # InFlightExitOutputWithdrawn
    contracts_naming = [{"exitId", :in_flight_exit_id}, {"outputIndex", :output_index}]
    key = :piggyback_type
    value = :output
    Map.update(reduce_naming(data, contracts_naming), :omg_data, %{key => value}, &Map.put(&1, key, value))
  end

  # def rename(data, %ABI.FunctionSelector{function: "startInFlightExit"}) do
  #   contracts_naming = [
  #     {"inFlightTx", :in_flight_tx},
  #     {"inputTxs", :input_txs},
  #     {"inputUtxosPos", :input_utxos_pos},
  #     {"inputTxsInclusionProofs", :input_inclusion_proofs},
  #     {"inFlightTxWitnesses", :in_flight_tx_sigs}
  #   ]

  #   reduce_naming(data, contracts_naming)
  # end

  # def rename(data, %ABI.FunctionSelector{function: "startStandardExit"}) do
  #   contracts_naming = [
  #     {"outputTxInclusionProof", :output_tx_inclusion_proof},
  #     {"rlpOutputTx", :output_tx},
  #     {"utxoPos", :utxo_pos}
  #   ]

  #   # not used and discarded
  #   Map.delete(reduce_naming(data, contracts_naming), :output_tx_inclusion_proof)
  # end

  # # workaround for https://github.com/omgnetwork/elixir-omg/issues/1632
  # def rename(data, %ABI.FunctionSelector{function: "startExit"}) do
  #   contracts_naming = [
  #     {"utxoPosToExit", :utxo_pos},
  #     {"rlpOutputTxToContract", :output_tx},
  #     {"outputTxToContractInclusionProof", :output_tx_inclusion_proof},
  #     {"rlpInputCreationTx", :rlp_input_creation_tx},
  #     {"inputCreationTxInclusionProof", :input_creation_tx_inclusion_proof},
  #     {"utxoPosInput", :utxo_pos_input}
  #   ]

  #   # not used and discarded
  #   Map.drop(reduce_naming(data, contracts_naming), [
  #     :output_tx_inclusion_proof,
  #     :rlp_input_creation_tx,
  #     :input_creation_tx_inclusion_proof,
  #     :utxo_pos_input
  #   ])
  # end

  # def rename(data, %ABI.FunctionSelector{function: "challengeInFlightExitNotCanonical"}) do
  #   contracts_naming = [
  #     {"competingTx", :competing_tx},
  #     {"competingTxInclusionProof", :competing_tx_inclusion_proof},
  #     {"competingTxInputIndex", :competing_tx_input_index},
  #     {"competingTxPos", :competing_tx_pos},
  #     {"competingTxWitness", :competing_tx_sig},
  #     {"inFlightTx", :in_flight_tx},
  #     {"inFlightTxInputIndex", :in_flight_input_index},
  #     {"inputTx", :input_tx_bytes},
  #     {"inputUtxoPos", :input_utxo_pos}
  #   ]

  #   # not used and discarded
  #   Map.delete(reduce_naming(data, contracts_naming), :competing_tx_inclusion_proof)
  # end

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
