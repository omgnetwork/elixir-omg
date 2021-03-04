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

defmodule Support.WatcherHelper do
  @moduledoc """
  Module provides common testing functions used by App's tests.
  """
  alias ExUnit.CaptureLog
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Watcher.Utxo

  require Utxo

  import ExUnit.Assertions
  import Plug.Conn
  import Phoenix.ConnTest
  @endpoint OMG.WatcherRPC.Web.Endpoint

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
    version = Map.get(response_body, "version")

    %{"version" => ^version, "success" => true, "data" => data} = response_body
    data
  end

  def no_success?(path, body \\ nil) do
    response_body = rpc_call(path, body, 200)
    version = Map.get(response_body, "version")
    %{"version" => ^version, "success" => false, "data" => data} = response_body
    data
  end

  def server_error?(path, body \\ nil) do
    response_body = rpc_call(path, body, 500)
    version = Map.get(response_body, "version")
    %{"version" => ^version, "success" => false, "data" => data} = response_body
    data
  end

  def rpc_call(path, body \\ nil, expected_resp_status \\ 200) do
    response =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post(path, body)

    # CORS check
    assert ["*"] == get_resp_header(response, "access-control-allow-origin")

    required_headers = [
      "access-control-allow-origin",
      "access-control-expose-headers",
      "access-control-allow-credentials"
    ]

    for header <- required_headers do
      assert header in Enum.map(response.resp_headers, &elem(&1, 0))
    end

    # CORS check
    assert response.status == expected_resp_status
    Jason.decode!(response.resp_body)
  end

  def create_topic(main_topic, subtopic), do: main_topic <> ":" <> subtopic

  @doc """
  Decodes specified keys in map from hex to binary
  """
  @spec decode16(map(), list()) :: map()
  def decode16(data, keys) do
    keys
    |> Enum.into(%{}, &decode16_for_key(data, &1))
    |> (&Map.merge(data, &1)).()
  end

  defp decode16_for_key(data, key) do
    case data[key] do
      value when is_binary(value) ->
        {key, decode_binary!(value)}

      value when is_list(value) ->
        bin_list =
          value
          |> Enum.map(&Encoding.from_hex/1)
          |> Enum.map(fn {:ok, bin} -> bin end)

        {key, bin_list}
    end
  end

  defp decode_binary!(value) do
    {:ok, bin} = Encoding.from_hex(value)
    bin
  end

  def get_balance(address, token) do
    encoded_token = Encoding.to_hex(token)

    address
    |> get_balance()
    |> Enum.find(%{"amount" => 0}, fn %{"currency" => currency} -> encoded_token == currency end)
    |> Map.get("amount")
  end

  def get_utxos(params) when is_map(params) do
    hex_string_address = Encoding.to_hex(params.address)
    success?("/account.get_utxos", %{params | address: hex_string_address})
  end

  @doc """
  shortcut helper for get_utxos that inject pagination data for you
  """
  def get_utxos(address, page \\ 1, limit \\ 100) do
    success?("/account.get_utxos", %{"address" => Encoding.to_hex(address), "page" => page, "limit" => limit})
  end

  def get_exitable_utxos(address) do
    success?("/account.get_exitable_utxos", %{"address" => Encoding.to_hex(address)})
  end

  def get_balance(address) do
    success?("/account.get_balance", %{"address" => Encoding.to_hex(address)})
  end

  def get_block(blknum) do
    response_body = rpc_call("block.get", %{blknum: blknum}, 200)

    case response_body do
      %{"success" => false, "data" => error} -> {:error, error}
      %{"success" => true, "data" => block} -> {:ok, block}
    end
  end

  def get_exit_data(blknum, txindex, oindex) do
    get_exit_data(Utxo.Position.encode(Utxo.position(blknum, txindex, oindex)))
  end

  def get_exit_challenge(blknum, txindex, oindex) do
    utxo_pos = Utxo.position(blknum, txindex, oindex) |> Utxo.Position.encode()

    data = success?("utxo.get_challenge_data", %{utxo_pos: utxo_pos})

    decode16(data, ["exiting_tx", "txbytes", "sig"])
  end

  def get_in_flight_exit(transaction) do
    exit_data = success?("in_flight_exit.get_data", %{txbytes: Encoding.to_hex(transaction)})

    decode16(exit_data, ["in_flight_tx", "input_txs", "input_txs_inclusion_proofs", "in_flight_tx_sigs"])
  end

  def get_in_flight_exit_competitors(transaction) do
    competitor_data = success?("in_flight_exit.get_competitor", %{txbytes: Encoding.to_hex(transaction)})

    decode16(competitor_data, ["in_flight_txbytes", "competing_txbytes", "competing_sig", "competing_proof", "input_tx"])
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
      "spending_txbytes",
      "spending_sig",
      "input_tx"
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
      "in_flight_proof",
      "spending_txbytes",
      "spending_sig"
    ])
  end

  def capture_log(function, max_waiting_ms \\ 2_000) do
    CaptureLog.capture_log(fn ->
      logs = CaptureLog.capture_log(fn -> function.() end)

      case logs do
        "" -> wait_for_log(max_waiting_ms)
        logs -> logs
      end
    end)
  end

  defp wait_for_log(max_waiting_ms, sleep_time_ms \\ 20) do
    steps = :erlang.ceil(max_waiting_ms / sleep_time_ms)

    Enum.reduce_while(1..steps, nil, fn _, _ ->
      logs = CaptureLog.capture_log(fn -> Process.sleep(sleep_time_ms) end)

      case logs do
        "" -> {:cont, ""}
        logs -> {:halt, logs}
      end
    end)
  end

  defp get_exit_data(encoded_position) do
    data = success?("utxo.get_exit_data", %{utxo_pos: encoded_position})
    decode16(data, ["txbytes", "proof"])
  end
end
