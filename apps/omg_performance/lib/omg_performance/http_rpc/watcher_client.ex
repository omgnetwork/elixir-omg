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
  Provides access to Watcher's RPC API, as required by the `OMG.Performance` tool


  TODO: This module includes a big fat copy paster from `Support.WatcherHelper` - do sth about this later
  We need an exact set of functionalities from the `omg_performance`'s Watcher client, but they're executed
  differently, because in here we're calling the Watcher's API on a slightly different level (full HTTP stack)
  Differences:
   - atoms not strings as keys
   - don't have the many helpers to assert `success?`/`no_success?` etc., success is always expected
  """

  alias OMG.Utils.HttpRPC.ClientAdapter
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utxo

  require Utxo

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_balance(address, token) do
    encoded_token = Encoding.to_hex(token)

    address
    |> get_balance()
    |> Enum.find(%{"amount" => 0}, fn %{"currency" => currency} -> encoded_token == currency end)
    |> Map.get("amount")
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_utxos(address) do
    call("/account.get_utxos", %{:address => Encoding.to_hex(address)})
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_exitable_utxos(address) do
    call("/account.get_exitable_utxos", %{:address => Encoding.to_hex(address)})
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_balance(address) do
    call("/account.get_balance", %{:address => Encoding.to_hex(address)})
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_exit_data(blknum, txindex, oindex),
    do: get_exit_data(Utxo.Position.encode(Utxo.position(blknum, txindex, oindex)))

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_exit_data(encoded_position) do
    data = call("utxo.get_exit_data", %{utxo_pos: encoded_position})
    ClientAdapter.decode16(data, [:txbytes, :proof])
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_exit_challenge(utxo_pos) do
    data = call("utxo.get_challenge_data", %{utxo_pos: utxo_pos})

    ClientAdapter.decode16(data, [:exiting_tx, :txbytes, :sig])
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_in_flight_exit(transaction) do
    exit_data = call("in_flight_exit.get_data", %{txbytes: Encoding.to_hex(transaction)})

    ClientAdapter.decode16(exit_data, [:in_flight_tx, :input_txs, :input_txs_inclusion_proofs, :in_flight_tx_sigs])
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_in_flight_exit_competitors(transaction) do
    competitor_data = call("in_flight_exit.get_competitor", %{txbytes: Encoding.to_hex(transaction)})

    ClientAdapter.decode16(competitor_data, [
      :in_flight_txbytes,
      :competing_txbytes,
      :competing_sig,
      :competing_proof,
      :input_tx
    ])
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_prove_canonical(transaction) do
    competitor_data = call("in_flight_exit.prove_canonical", %{txbytes: Encoding.to_hex(transaction)})

    ClientAdapter.decode16(competitor_data, [:in_flight_txbytes, :in_flight_proof])
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def submit(transaction) do
    submission_info = call("transaction.submit", %{transaction: Encoding.to_hex(transaction)})

    ClientAdapter.decode16(submission_info, ["txhash"])
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_input_challenge_data(transaction, input_index) do
    proof_data =
      call("in_flight_exit.get_input_challenge_data", %{
        txbytes: Encoding.to_hex(transaction),
        input_index: input_index
      })

    ClientAdapter.decode16(proof_data, [
      :in_flight_txbytes,
      :spending_txbytes,
      :spending_sig,
      :input_tx
    ])
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_output_challenge_data(transaction, output_index) do
    proof_data =
      call("in_flight_exit.get_output_challenge_data", %{
        txbytes: Encoding.to_hex(transaction),
        output_index: output_index
      })

    ClientAdapter.decode16(proof_data, [
      :in_flight_txbytes,
      :in_flight_proof,
      :spending_txbytes,
      :spending_sig
    ])
  end

  @doc """
  Copied from `Support.WatcherHelper`, see moduledoc
  """
  def get_status() do
    call("status.get", %{})
  end

  defp call(path, body) do
    url = Application.fetch_env!(:omg_performance, :watcher_url)
    {:ok, response} = ClientAdapter.rpc_post(body, path, url) |> ClientAdapter.get_response_body()
    response
  end
end
