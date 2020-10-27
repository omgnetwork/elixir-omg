# Copyright 2019-2020 OmiseGO Pte Ltd
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
# limitations under the License.w

defmodule LoadTest.WatcherInfo.Utxo do
  @moduledoc """
  Functions for retrieving utxos through WatcherInfo API.
  """
  require Logger

  alias LoadTest.Connection.WatcherInfo
  alias LoadTest.Ethereum.Account
  alias LoadTest.Service.Sync
  alias LoadTest.Utils.Encoding

  @poll_timeout 60_000

  @spec get_utxos(Account.addr_t(), ExPlasma.Utxo.t() | nil | :empty) :: {:ok, [] | ExPlasma.Utxo.t()} | no_return
  def get_utxos(sender, utxo \\ nil) do
    Sync.repeat_until_success(
      fn ->
        fetch_utxos(sender, utxo)
      end,
      @poll_timeout,
      "Failed to fetch utxos"
    )
  end

  defp fetch_utxos(sender, utxo) do
    case WatcherInfoAPI.Api.Account.account_get_utxos(
           WatcherInfo.client(),
           %WatcherInfoAPI.Model.AddressBodySchema1{
             address: Encoding.to_hex(sender.addr)
           }
         ) do
      {:ok, result} ->
        result.body
        |> Jason.decode!()
        |> find_utxo(utxo)

      other ->
        other
    end
  end

  defp find_utxo(decoded_response, utxo) do
    case utxo do
      nil ->
        {:ok, decoded_response}

      :empty ->
        case decoded_response["data"] do
          [] -> {:ok, []}
          other -> {:error, other}
        end

      _data ->
        do_find_utxo(decoded_response, utxo)
    end
  end

  defp do_find_utxo(response, utxo) do
    found_utxo =
      Enum.find(response["data"], fn %{
                                       "amount" => amount,
                                       "blknum" => blknum,
                                       "currency" => currency,
                                       "oindex" => oindex,
                                       "otype" => otype,
                                       "owner" => owner,
                                       "txindex" => txindex
                                     } ->
        current_utxo = %ExPlasma.Utxo{
          amount: amount,
          blknum: blknum,
          currency: Encoding.to_binary(currency),
          oindex: oindex,
          output_type: otype,
          owner: Encoding.to_binary(owner),
          txindex: txindex
        }

        current_utxo == utxo
      end)

    case found_utxo do
      nil -> {:error, response}
      _ -> {:ok, found_utxo}
    end
  end
end
