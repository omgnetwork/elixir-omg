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

defmodule OMG.Performance.HttpRPC.WatcherClient do
  @moduledoc """
  Provides access to Watcher's RPC API
  """

  alias OMG.Utils.HttpRPC.ClientAdapter
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utxo

  require Utxo

  #
  # TODO: here begins a big fat copy paster from `watcher_helper.ex` - do sth about this later
  #
  def get_balance(address, token) do
    encoded_token = Encoding.to_hex(token)

    address
    |> get_balance()
    |> Enum.find(%{"amount" => 0}, fn %{"currency" => currency} -> encoded_token == currency end)
    |> Map.get("amount")
  end

  def get_utxos(address) do
    success?("/account.get_utxos", %{:address => Encoding.to_hex(address)})
  end

  def get_exitable_utxos(address) do
    success?("/account.get_exitable_utxos", %{:address => Encoding.to_hex(address)})
  end

  def get_balance(address) do
    success?("/account.get_balance", %{:address => Encoding.to_hex(address)})
  end

  def get_exit_data(blknum, txindex, oindex),
    do: get_exit_data(Utxo.Position.encode(Utxo.position(blknum, txindex, oindex)))

  def get_exit_data(encoded_position) do
    data = success?("utxo.get_exit_data", %{utxo_pos: encoded_position})
    decode_response(data, [:txbytes, :proof])
  end

  def get_exit_challenge(utxo_pos) do
    data = success?("utxo.get_challenge_data", %{utxo_pos: utxo_pos})

    decode_response(data, [:exiting_tx, :txbytes, :sig])
  end

  def get_in_flight_exit(transaction) do
    exit_data = success?("in_flight_exit.get_data", %{txbytes: Encoding.to_hex(transaction)})

    decode_response(exit_data, [:in_flight_tx, :input_txs, :input_txs_inclusion_proofs, :in_flight_tx_sigs])
  end

  def get_in_flight_exit_competitors(transaction) do
    competitor_data = success?("in_flight_exit.get_competitor", %{txbytes: Encoding.to_hex(transaction)})

    decode_response(competitor_data, [
      :in_flight_txbytes,
      :competing_txbytes,
      :competing_sig,
      :competing_proof,
      :input_tx
    ])
  end

  def get_prove_canonical(transaction) do
    competitor_data = success?("in_flight_exit.prove_canonical", %{txbytes: Encoding.to_hex(transaction)})

    decode_response(competitor_data, [:in_flight_txbytes, :in_flight_proof])
  end

  def submit(transaction) do
    submission_info = success?("transaction.submit", %{transaction: Encoding.to_hex(transaction)})

    decode_response(submission_info, ["txhash"])
  end

  def get_input_challenge_data(transaction, input_index) do
    proof_data =
      success?("in_flight_exit.get_input_challenge_data", %{
        txbytes: Encoding.to_hex(transaction),
        input_index: input_index
      })

    decode_response(proof_data, [
      :in_flight_txbytes,
      :spending_txbytes,
      :spending_sig,
      :input_tx
    ])
  end

  def get_output_challenge_data(transaction, output_index) do
    proof_data =
      success?("in_flight_exit.get_output_challenge_data", %{
        txbytes: Encoding.to_hex(transaction),
        output_index: output_index
      })

    decode_response(proof_data, [
      :in_flight_txbytes,
      :in_flight_proof,
      :spending_txbytes,
      :spending_sig
    ])
  end

  # here ends the copy-paste
  #

  # some functions that I added, following the copy-pasted convention above

  def get_status() do
    success?("status.get", %{})
  end

  # here are some copy-paste-related functions to get it off the ground
  # FIXME: we're not asserting success here, rename
  defp success?(path, body) do
    watcher_url = Application.fetch_env!(:omg_performance, :watcher_url)
    {:ok, data} = call(body, path, watcher_url)
  end

  # end those functions here

  defp call(params, path, url),
    do: ClientAdapter.rpc_post(params, path, url) |> ClientAdapter.get_response_body()

  defp decode_response({:ok, response}, keys), do: {:ok, ClientAdapter.decode16(response, keys)}
  defp decode_response(other, _), do: other
end
