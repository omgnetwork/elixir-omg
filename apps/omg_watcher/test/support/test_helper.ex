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

  alias OMG.API.Crypto
  alias OMG.API.Utxo

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
    request = conn(:post, path, body)
    response = request |> send_request
    assert response.status == expected_resp_status
    Poison.decode!(response.resp_body)
  end

  defp send_request(req) do
    req
    |> put_private(:plug_skip_csrf_protection, true)
    |> OMG.Watcher.Web.Endpoint.call([])
  end

  def create_topic(main_topic, subtopic), do: main_topic <> ":" <> subtopic

  def to_response_address(address) do
    "0X" <> encoded =
      address
      |> OMG.API.Crypto.encode_address!()
      |> String.upcase()

    encoded
  end

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

        case is_binary(value) && Base.decode16(value, case: :mixed) do
          {:ok, newvalue} -> {key, newvalue}
          _ -> {key, value}
        end
      end
    )
    |> (&Map.merge(data, &1)).()
  end

  def get_utxos(address) do
    {:ok, address_encode} = Crypto.encode_address(address)
    success?("/account.get_utxos", %{"address" => address_encode})
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
   exit_data = success?("inflight_exit.get_data", %{txbytes: transaction})

   decode16(exit_data, ["in_flight_tx", "input_txs", "input_txs_inclusion_proofs", "in_flight_tx_sigs"])
  end
end
