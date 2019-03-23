# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.TestHelper do
  @moduledoc """
  Module provides common testing functions used by App's tests.
  """

  alias OMG.RPC.Web.Encoding
  alias OMG.Utxo

  require Utxo

  import ExUnit.Assertions
  use Plug.Test

  def wait_for_process(pid, timeout \\ :infinity) when is_pid(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _, _} ->
        :ok
    after
      timeout ->
        throw({:timeouted_waiting_for, pid})
    end
  end

  def success?(path, body \\ nil) do
    response_body = rpc_call(path, body, 200)
    %{"version" => "1.0", "success" => true, "data" => data} = response_body
    data
  end

  def no_success?(path, body \\ nil) do
    response_body = rpc_call(path, body, 200)
    %{"version" => "1.0", "success" => false, "data" => data} = response_body
    data
  end

  def server_error?(path, body \\ nil) do
    response_body = rpc_call(path, body, 500)
    %{"version" => "1.0", "success" => false, "data" => data} = response_body
    data
  end

  def rpc_call(path, body \\ nil, expected_resp_status \\ 200) do
    request =
      conn(:post, path, body)
      |> put_req_header("content-type", "application/json")

    response = request |> send_request
    assert response.status == expected_resp_status
    Poison.decode!(response.resp_body)
  end

  defp send_request(req) do
    req
    |> OMG.Watcher.Web.Endpoint.call([])
  end

  def create_topic(main_topic, subtopic), do: main_topic <> ":" <> subtopic

  @doc """
  Decodes specified keys in map from hex to binary
  """
  @spec decode16(map(), list()) :: map()
  def decode16(data, keys) do
    keys
    |> Enum.filter(&Map.has_key?(data, &1))
    |> Enum.into(
      %{},
      fn key ->
        value = data[key]

        with true <- is_binary(value),
             {:ok, bin} <- Encoding.from_hex(value) do
          {key, bin}
        else
          _ -> {key, value}
        end
      end
    )
    |> (&Map.merge(data, &1)).()
  end

  def get_balance(address, token) do
    encoded_token = Encoding.to_hex(token)

    address
    |> get_balance()
    |> Enum.find(%{"amount" => 0}, fn %{"currency" => currency} -> encoded_token == currency end)
    |> Map.get("amount")
  end

  def get_utxos(address) do
    success?("/account.get_utxos", %{"address" => Encoding.to_hex(address)})
  end

  def get_balance(address) do
    success?("/account.get_balance", %{"address" => Encoding.to_hex(address)})
  end

  def get_exit_data(blknum, txindex, oindex) do
    utxo_pos = Utxo.Position.encode({:utxo_position, blknum, txindex, oindex})

    data = success?("utxo.get_exit_data", %{utxo_pos: utxo_pos})

    decode16(data, ["txbytes", "proof", "sigs"])
  end

  def get_exit_challenge(blknum, txindex, oindex) do
    utxo_pos = Utxo.position(blknum, txindex, oindex) |> Utxo.Position.encode()

    data = success?("utxo.get_challenge_data", %{utxo_pos: utxo_pos})

    decode16(data, ["txbytes", "sig"])
  end

  def get_in_flight_exit(transaction) do
    exit_data = success?("in_flight_exit.get_data", %{txbytes: Encoding.to_hex(transaction)})

    decode16(exit_data, ["in_flight_tx", "input_txs", "input_txs_inclusion_proofs", "in_flight_tx_sigs"])
  end

  def get_in_flight_exit_competitors(transaction) do
    competitor_data = success?("in_flight_exit.get_competitor", %{txbytes: Encoding.to_hex(transaction)})

    decode16(competitor_data, ["in_flight_txbytes", "competing_txbytes", "competing_sig", "competing_proof"])
  end

  def get_prove_canonical(transaction) do
    competitor_data = success?("in_flight_exit.prove_canonical", %{txbytes: Encoding.to_hex(transaction)})

    decode16(competitor_data, ["in_flight_txbytes", "in_flight_proof"])
  end

  def submit(transaction) do
    submission_info = success?("transaction.submit", %{transaction: Encoding.to_hex(transaction)})

    decode16(submission_info, ["txhash"])
  end

  def get_input_challenge_data(transaction, input_index) do
    proof_data =
      success?("in_flight_exit.get_input_challenge_data", %{
        txbytes: Encoding.to_hex(transaction),
        input_index: input_index
      })

    decode16(proof_data, [
      "in_flight_txbytes",
      "in_flight_input_index",
      "spending_txbytes",
      "spending_input_index",
      "spending_sig"
    ])
  end

  def get_output_challenge_data(transaction, output_index) do
    proof_data =
      success?("in_flight_exit.get_output_challenge_data", %{
        txbytes: Encoding.to_hex(transaction),
        output_index: output_index
      })

    decode16(proof_data, [
      "in_flight_txbytes",
      "in_flight_output_pos",
      "in_flight_proof",
      "spending_txbytes",
      "spending_input_index",
      "spending_sig"
    ])
  end
end
