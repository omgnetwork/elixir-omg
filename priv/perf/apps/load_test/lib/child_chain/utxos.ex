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
# limitations under the License.

defmodule LoadTest.ChildChain.Utxos do
  @moduledoc """
  Utility functions for utxos
  """
  alias ExPlasma.Encoding
  alias ExPlasma.Utxo
  alias LoadTest.Connection.WatcherInfo, as: Connection
  alias WatcherInfoAPI.Api
  alias WatcherInfoAPI.Model

  @doc """
  Returns an addresses utxos.
  """
  @spec get_utxos(Utxo.address_binary()) :: list(Utxo.t())
  def get_utxos(address) do
    {:ok, response} =
      Api.Account.account_get_utxos(
        Connection.client(),
        %Model.AddressBodySchema1{
          address: Encoding.to_hex(address)
        }
      )

    utxos = Jason.decode!(response.body)["data"]

    Enum.map(
      utxos,
      fn x ->
        %Utxo{
          blknum: x["blknum"],
          txindex: x["txindex"],
          oindex: x["oindex"],
          currency: x["currency"],
          amount: x["amount"]
        }
      end
    )
  end

  @doc """
  Returns the highest value utxo of a given currency
  """
  @spec get_largest_utxo(list(Utxo.t()), Utxo.address_binary()) :: Utxo.t()
  def get_largest_utxo([], _currency), do: nil

  def get_largest_utxo(utxos, currency) do
    utxos
    |> Enum.filter(fn utxo -> currency == LoadTest.Utils.Encoding.from_hex(utxo.currency) end)
    |> Enum.max_by(fn x -> x.amount end, fn -> nil end)
  end
end
