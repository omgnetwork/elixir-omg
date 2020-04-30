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
  alias LoadTest.ChildChain.Transaction
  alias LoadTest.Connection.WatcherInfo, as: Connection
  alias WatcherInfoAPI.Api
  alias WatcherInfoAPI.Model

  @doc """
  Returns an addresses utxos.
  """
  @spec get_utxos(Utxo.address_binary()) :: list(Utxo.t())
  def get_utxos(address) do
    body = %Model.AddressBodySchema1{
      address: Encoding.to_hex(address)
    }

    {:ok, response} = Api.Account.account_get_utxos(Connection.client(), body)

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

  @doc """
  Merges all the given utxos into one.
  Note that this can take several iterations to complete.
  """
  @spec merge(list(Utxo.t()), Utxo.address_binary(), Account.t()) :: Utxo.t()
  def merge(utxos, currency, faucet_account) do
    utxos
    |> Enum.filter(fn utxo -> LoadTest.Utils.Encoding.from_hex(utxo.currency) == currency end)
    |> merge(faucet_account)
  end

  @spec merge(list(Utxo.t()), Account.t()) :: Utxo.t()
  defp merge([], _faucet_account), do: :error_empty_utxo_list
  defp merge([single_utxo], _faucet_account), do: single_utxo

  defp merge(utxos, faucet_account) when length(utxos) > 4 do
    utxos
    |> Enum.chunk_every(4)
    |> Enum.map(fn inputs -> merge(inputs, faucet_account) end)
    |> merge(faucet_account)
  end

  defp merge([%{currency: currency} | _] = inputs, faucet_account) do
    tx_amount = Enum.reduce(inputs, 0, fn x, acc -> x.amount + acc end)
    output = %Utxo{amount: tx_amount, currency: currency, owner: faucet_account.addr}

    [utxo] =
      Transaction.submit_tx(
        inputs,
        [output],
        List.duplicate(faucet_account, length(inputs))
      )

    utxo
  end
end
