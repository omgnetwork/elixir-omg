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

defmodule OMG.Utils.HttpRPC.Client do
  @moduledoc """
  Provides functions to communicate with Child Chain API
  """

  alias OMG.Utils.HttpRPC.Adapter
  alias OMG.Utils.HttpRPC.Encoding

  require Logger

  @type response_t() ::
          {:ok, %{required(atom()) => any()}}
          | {:error,
             {:client_error | :server_error, any()}
             | {:malformed_response, any() | {:error, :invalid}}}

  @doc """
  Gets Block of given hash
  """
  @spec get_block(binary(), binary()) :: response_t()
  def get_block(hash, url), do: call(%{hash: Encoding.to_hex(hash)}, "block.get", url)

  def get_exit_data(encoded_position, url), do: call(%{utxo_pos: encoded_position}, "utxo.get_exit_data", url)

  def get_exitable_utxos(address, url), do: call(%{address: address}, "account.get_exitable_utxos", url)

  @doc """
  Submits transaction
  """
  @spec submit(binary(), binary()) :: response_t()
  def submit(tx, url), do: call(%{transaction: Encoding.to_hex(tx)}, "transaction.submit", url)

  @doc """
  Gets Watcher status
  """
  @spec get_status(binary()) :: response_t()
  def get_status(url), do: call(%{}, "status.get", url)

  def get_in_flight_exit(txbytes, url), do: call(%{txbytes: txbytes}, "in_flight_exit.get_data", url)

  defp call(params, path, url),
    do: Adapter.rpc_post(params, path, url) |> Adapter.get_response_body() |> decode_response()

  # Translates response's body to known elixir structure, either block or tx submission response or error.
  defp decode_response({:ok, %{transactions: transactions, blknum: number, hash: hash}}) do
    {:ok,
     %{
       number: number,
       hash: decode16!(hash),
       transactions: Enum.map(transactions, &decode16!/1)
     }}
  end

  defp decode_response({:ok, %{txhash: _hash} = response}) do
    {:ok, Map.update!(response, :txhash, &decode16!/1)}
  end

  defp decode_response({:ok, %{proof: proof, sigs: sigs, txbytes: txbytes, utxo_pos: utxo_pos}}) do
    {:ok,
     %{
       proof: decode16!(proof),
       sigs: decode16!(sigs),
       txbytes: decode16!(txbytes),
       utxo_pos: utxo_pos
     }}
  end

  defp decode_response(error), do: error

  defp decode16!(hexstr) do
    {:ok, bin} = Encoding.from_hex(hexstr)
    bin
  end
end
