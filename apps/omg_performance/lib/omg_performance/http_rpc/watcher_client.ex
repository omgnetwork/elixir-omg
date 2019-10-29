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

  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Watcher.HttpRPC.Adapter

  @address_bytes_size 20

  @doc """
  Gets Watcher status
  """
  @spec get_status(binary()) :: OMG.Watcher.HttpRPC.Client.response_t()
  def get_status(url), do: call(%{}, "status.get", url)

  @doc """
  Gets standard exit data from Watcher's RPC
  """
  @spec get_exit_data(non_neg_integer(), binary()) :: OMG.Watcher.HttpRPC.Client.response_t()
  def get_exit_data(encoded_position, url),
    do:
      %{utxo_pos: encoded_position}
      |> call("utxo.get_exit_data", url)
      |> decode_response()

  @doc """
  Gets utxo for given address from Watcher's RPC
  """
  @spec get_exitable_utxos(OMG.Crypto.address_t(), binary()) :: OMG.Watcher.HttpRPC.Client.response_t()
  def get_exitable_utxos(address, url) when is_binary(address) and byte_size(address) == @address_bytes_size,
    do: call(%{address: Encoding.to_hex(address)}, "account.get_exitable_utxos", url)

  def get_exit_challenge(utxo_pos, url) do
    %{utxo_pos: utxo_pos}
    |> call("utxo.get_challenge_data", url)
    |> decode_response()
  end

  defp call(params, path, url),
    do: Adapter.rpc_post(params, path, url) |> Adapter.get_response_body()

  defp decode_response({:ok, %{proof: proof, txbytes: txbytes, utxo_pos: utxo_pos}}) do
    {:ok,
     %{
       proof: decode16!(proof),
       txbytes: decode16!(txbytes),
       utxo_pos: utxo_pos
     }}
  end

  defp decode_response(
         {:ok, %{exiting_tx: exiting_tx, txbytes: txbytes, sig: sig, exit_id: exit_id, input_index: input_index}}
       ) do
    {:ok,
     %{
       exit_id: exit_id,
       input_index: input_index,
       exiting_tx: decode16!(exiting_tx),
       txbytes: decode16!(txbytes),
       sig: decode16!(sig)
     }}
  end

  defp decode_response(error), do: error

  defp decode16!(hexstr) do
    {:ok, bin} = Encoding.from_hex(hexstr)
    bin
  end
end
