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

defmodule OMG.Watcher.ExitProcessor.Piggyback do
  @moduledoc """
  Encapsulates managing and executing the behaviors related to treating exits by the child chain and watchers
  Keeps a state of exits that are in progress, updates it with news from the root chain, compares to the
  state of the ledger (`OMG.State`), issues notifications as it finds suitable.

  Should manage all kinds of exits allowed in the protocol and handle the interactions between them.

  This is the functional, zero-side-effect part of the exit processor. Logic should go here:
    - orchestrating the persistence of the state
    - finding invalid exits, disseminating them as events according to rules
    - enabling to challenge invalid exits
    - figuring out critical failure of invalid exit challenging (aka `:unchallenged_exit` event)
    - MoreVP protocol managing in general

  For the imperative shell, see `OMG.Watcher.ExitProcessor`
  """

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.DoubleSpend
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo
  alias OMG.Watcher.ExitProcessor.KnownTx

  import OMG.Watcher.ExitProcessor.Tools

  require Transaction.Payment

  use OMG.Utils.LoggerExt

  @type piggyback_type_t() :: :input | :output
  @type piggyback_t() :: {piggyback_type_t(), non_neg_integer()}

  @type input_challenge_data :: %{
          in_flight_txbytes: Transaction.tx_bytes(),
          in_flight_input_index: 0..3,
          spending_txbytes: Transaction.tx_bytes(),
          spending_input_index: 0..3,
          spending_sig: <<_::520>>,
          input_tx: Transaction.tx_bytes(),
          input_utxo_pos: OMG.InputPointer.utxo_pos_tuple()
        }

  @type output_challenge_data :: %{
          in_flight_txbytes: Transaction.tx_bytes(),
          in_flight_output_pos: pos_integer(),
          in_flight_input_index: 4..7,
          spending_txbytes: Transaction.tx_bytes(),
          spending_input_index: 0..3,
          spending_sig: <<_::520>>
        }

  @type piggyback_challenge_data_error() ::
          :ife_not_known_for_tx
          | Transaction.decode_error()
          | :no_double_spend_on_particular_piggyback

  def get_input_challenge_data(request, state, txbytes, input_index) do
    case input_index in 0..(Transaction.Payment.max_inputs() - 1) do
      true -> get_piggyback_challenge_data(request, state, txbytes, {:input, input_index})
      false -> {:error, :piggybacked_index_out_of_range}
    end
  end

  def get_output_challenge_data(request, state, txbytes, output_index) do
    case output_index in 0..(Transaction.Payment.max_outputs() - 1) do
      true -> get_piggyback_challenge_data(request, state, txbytes, {:output, output_index})
      false -> {:error, :piggybacked_index_out_of_range}
    end
  end

  @spec get_invalid_piggybacks_events(Core.t(), KnownTx.known_txs_by_input_t()) ::
          list(Event.InvalidPiggyback.t())
  def get_invalid_piggybacks_events(%Core{in_flight_exits: ifes}, known_txs_by_input) do
    ifes
    |> Map.values()
    |> all_invalid_piggybacks_by_ife(known_txs_by_input)
    |> group_by_txbytes()
    |> materials_to_events()
  end

  defp all_invalid_piggybacks_by_ife(ifes_values, known_txs_by_input) do
    [:input, :output]
    |> Enum.flat_map(fn pb_type -> invalid_piggybacks_by_ife(known_txs_by_input, pb_type, ifes_values) end)
  end

  # we need to produce only one event per IFE, with both piggybacks on inputs and outputs
  defp group_by_txbytes(invalid_piggybacks) do
    invalid_piggybacks
    |> Enum.map(fn {ife, type, materials} -> {Transaction.raw_txbytes(ife.tx), type, materials} end)
    |> Enum.group_by(&elem(&1, 0), fn {_, type, materials} -> {type, materials} end)
  end

  defp materials_to_events(invalid_piggybacks_by_txbytes) do
    invalid_piggybacks_by_txbytes
    |> Enum.map(fn {txbytes, type_materials_pairs} ->
      %Event.InvalidPiggyback{
        txbytes: txbytes,
        inputs: invalid_piggyback_indices(type_materials_pairs, :input),
        outputs: invalid_piggyback_indices(type_materials_pairs, :output)
      }
    end)
  end

  defp invalid_piggyback_indices(type_materials_pairs, pb_type) do
    # here we need to additionally group the materials found by type input/output
    # then we gut just the list of indices to present to the user in the event
    type_materials_pairs
    |> Enum.filter(fn {type, _materials} -> type == pb_type end)
    |> Enum.flat_map(fn {_type, materials} -> Map.keys(materials) end)
  end

  @spec invalid_piggybacks_by_ife(KnownTx.known_txs_by_input_t(), piggyback_type_t(), list(InFlightExitInfo.t())) ::
          list({InFlightExitInfo.t(), piggyback_type_t(), %{non_neg_integer => DoubleSpend.t()}})
  defp invalid_piggybacks_by_ife(known_txs_by_input, pb_type, ifes) do
    # getting invalid piggybacks on inputs
    ifes
    |> Enum.map(&InFlightExitInfo.indexed_piggybacks_by_ife(&1, pb_type))
    |> Enum.filter(&ife_has_something?/1)
    |> Enum.map(fn {ife, indexed_piggybacked_utxo_positions} ->
      proof_materials =
        DoubleSpend.all_double_spends_by_index(indexed_piggybacked_utxo_positions, known_txs_by_input, ife.tx)

      {ife, pb_type, proof_materials}
    end)
    |> Enum.filter(&ife_has_something?/1)
  end

  defp ife_has_something?({_ife, finds_for_ife}), do: !Enum.empty?(finds_for_ife)
  defp ife_has_something?({_ife, _, finds_for_ife}), do: !Enum.empty?(finds_for_ife)

  @spec get_piggyback_challenge_data(ExitProcessor.Request.t(), Core.t(), binary(), piggyback_t()) ::
          {:ok, input_challenge_data() | output_challenge_data()} | {:error, piggyback_challenge_data_error()}
  defp get_piggyback_challenge_data(%ExitProcessor.Request{blocks_result: blocks}, state, txbytes, piggyback) do
    with {:ok, tx} <- Transaction.decode(txbytes),
         {:ok, ife} <- get_ife(tx, state.in_flight_exits) do
      known_txs_by_input = KnownTx.get_all_from_blocks_appendix(blocks, state)
      produce_invalid_piggyback_proof(ife, known_txs_by_input, piggyback)
    end
  end

  @spec produce_invalid_piggyback_proof(InFlightExitInfo.t(), KnownTx.known_txs_by_input_t(), piggyback_t()) ::
          {:ok, input_challenge_data() | output_challenge_data()} | {:error, :no_double_spend_on_particular_piggyback}
  defp produce_invalid_piggyback_proof(ife, known_txs_by_input, {pb_type, pb_index} = piggyback) do
    with {:ok, proof_materials} <- get_proofs_for_particular_ife(ife, pb_type, known_txs_by_input),
         {:ok, proof} <- get_proof_for_particular_piggyback(pb_index, proof_materials) do
      {:ok, prepare_piggyback_challenge_response(ife, piggyback, proof)}
    end
  end

  # gets all proof materials for all possibly invalid piggybacks for a single ife, for a determined type (input/output)
  defp get_proofs_for_particular_ife(ife, pb_type, known_txs_by_input) do
    invalid_piggybacks_by_ife(known_txs_by_input, pb_type, [ife])
    |> case do
      [] -> {:error, :no_double_spend_on_particular_piggyback}
      # ife and pb_type are pinned here for a runtime sanity check - we got what we explicitly asked for
      [{^ife, ^pb_type, proof_materials}] -> {:ok, proof_materials}
    end
  end

  # gets any proof of a particular invalid piggyback, after we have figured the exact piggyback index affected
  defp get_proof_for_particular_piggyback(pb_index, proof_materials) do
    proof_materials
    |> Map.get(pb_index)
    |> case do
      nil -> {:error, :no_double_spend_on_particular_piggyback}
      # any challenging tx will do, taking the very first
      [proof | _] -> {:ok, proof}
    end
  end

  @spec prepare_piggyback_challenge_response(InFlightExitInfo.t(), piggyback_t(), DoubleSpend.t()) ::
          input_challenge_data() | output_challenge_data()
  defp prepare_piggyback_challenge_response(ife, {:input, input_index}, proof) do
    %{
      in_flight_txbytes: Transaction.raw_txbytes(ife.tx),
      in_flight_input_index: input_index,
      spending_txbytes: Transaction.raw_txbytes(proof.known_tx.signed_tx),
      spending_input_index: proof.known_spent_index,
      spending_sig: Enum.at(proof.known_tx.signed_tx.sigs, proof.known_spent_index),
      input_tx: Enum.at(ife.input_txs, input_index),
      input_utxo_pos: Enum.at(ife.input_utxos_pos, input_index)
    }
  end

  defp prepare_piggyback_challenge_response(ife, {:output, _output_index}, proof) do
    {_, inclusion_proof} = ife.tx_seen_in_blocks_at

    %{
      in_flight_txbytes: Transaction.raw_txbytes(ife.tx),
      in_flight_output_pos: proof.utxo_pos,
      in_flight_proof: inclusion_proof,
      spending_txbytes: Transaction.raw_txbytes(proof.known_tx.signed_tx),
      spending_input_index: proof.known_spent_index,
      spending_sig: Enum.at(proof.known_tx.signed_tx.sigs, proof.known_spent_index)
    }
  end
end
