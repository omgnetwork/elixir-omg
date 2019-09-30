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

  alias OMG.Utils.HttpRPC.Adapter
  alias OMG.Utils.HttpRPC.Encoding

  @doc """
  Gets Watcher status
  """
  @spec get_status(binary()) :: OMG.Utils.HttpRPC.Client.response_t()
  def get_status(url), do: call(%{}, "status.get", url)

  @doc """
  Gets standard exit data from Watcher's RPC
  """
  @spec get_exit_data(non_neg_integer(), binary()) :: OMG.Utils.HttpRPC.Client.response_t()
  def get_exit_data(encoded_position, url),
    do: "utxo.get_exit_data" |> call(%{utxo_pos: encoded_position}, url) |> decode_response()

  @doc """
  Gets utxo for given address from Watcher's RPC
  """
  @spec get_exitable_utxos(OMG.Crypto.address_t(), binary()) :: OMG.Utils.HttpRPC.Client.response_t()
  def get_exitable_utxos(address, url),
    do: "account.get_exitable_utxos" |> call(%{address: address}, url)

  defp call(path, params, url),
    do: Adapter.rpc_post(params, path, url) |> Adapter.get_response_body()

  defp decode_response({:ok, %{proof: proof, txbytes: txbytes, utxo_pos: utxo_pos}}) do
    {:ok,
     %{
       proof: decode16!(proof),
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
