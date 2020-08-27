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

defmodule OMG.WatcherInfo.UtxoSelection do
  @moduledoc """
  Provides Utxos selection and merging algorithms.
  """

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.WatcherInfo.DB

  require Transaction
  require Transaction.Payment

  @type currency_t() :: Transaction.Payment.currency()
  @type payment_t() :: %{
          owner: Crypto.address_t() | nil,
          currency: currency_t(),
          amount: pos_integer()
        }
  @type fee_t() :: %{
          currency: currency_t(),
          amount: non_neg_integer()
        }
  @type advice_t() :: utxos_map_t() | {:error, {:insufficient_funds, list(map())}} | {:error, :too_many_inputs}
  @type utxos_map_t() :: %{currency_t() => utxo_list_t()}
  @type utxo_list_t() :: list(%DB.TxOutput{})

  @doc """
  Defines and prioritises available UTXOs for stealth merge based on the available and selected sets.
  - Excludes currenices not already used in the transaction and UTXOs in the selected set.
  - Prioritises currencies that have the largest number of UTXOs
  - Sorts by ascending order of UTXO value within the currency groupings ("dust first").
  """
  @spec prioritize_merge_utxos(utxos_map_t(), list({currency_t(), utxo_list_t()})) :: utxo_list_t()
  def prioritize_merge_utxos(utxos, selected_utxos) do
    selected_utxo_hashes =
      selected_utxos
      |> Enum.flat_map(fn {_ccy, utxos} -> utxos end)
      |> Enum.reduce(%{}, fn utxo, acc -> Map.put(acc, utxo.child_chain_utxohash, true) end)

    case selected_utxo_hashes |> Map.keys() |> length() do
      0 ->
        []

      _ ->
        selected_utxos
        |> Enum.map(fn {ccy, _utxos} ->
          utxos[ccy]
          |> filter_unselected(selected_utxo_hashes)
          |> Enum.sort_by(fn utxo -> utxo.amount end, :asc)
        end)
        |> Enum.sort_by(&length/1, :desc)
        |> Enum.map(fn ccy_group -> Enum.slice(ccy_group, 0, 3) end)
        |> List.flatten()
    end
  end

  @doc """
  Given a map of UTXOs sufficient for the transaction and a set of available UTXOs,
  adds UTXOs to the transaction for "stealth merge" until the limit is reached or
  no UTXOs are available. Agnostic to the priority ordering of available UTXOs.
  Returns an updated map of UTXOs for the transaction.
  """
  @spec add_utxos_for_stealth_merge(utxo_list_t(), utxos_map_t()) :: utxos_map_t()
  def add_utxos_for_stealth_merge([], selected_utxos), do: selected_utxos

  def add_utxos_for_stealth_merge(available_utxos, selected_utxos) do
    case get_number_of_utxos(selected_utxos) do
      Transaction.Payment.max_inputs() ->
        selected_utxos

      _ ->
        [priority_utxo | remaining_available_utxos] = available_utxos

        stealth_merged_utxos =
          Map.update!(selected_utxos, priority_utxo.currency, fn current_utxos ->
            [priority_utxo | current_utxos]
          end)

        add_utxos_for_stealth_merge(remaining_available_utxos, stealth_merged_utxos)
    end
  end

  @doc """
  Given the available set of UTXOs and the needed amount by currency, tries to find a UTXO that satisfies the payment with no change.
  If this fails, starts to collect UTXOs (starting from the largest amount) until the payment is covered.
  Returns {currency, { variance, [utxos] }}. A `variance` greater than zero means insufficient funds.
  The ordering of UTXOs in descending order of amount is implicitly assumed for this algorithm to work deterministically.
  """
  @spec select_utxo(%{currency_t() => pos_integer()}, utxos_map_t()) ::
          list({currency_t(), {integer, utxo_list_t()}})
  def select_utxo(needed_funds, utxos) do
    Enum.map(needed_funds, fn {token, need} ->
      token_utxos = Map.get(utxos, token, [])

      {token,
       case Enum.find(token_utxos, fn %DB.TxOutput{amount: amount} -> amount == need end) do
         nil ->
           Enum.reduce_while(token_utxos, {need, []}, fn
             _, {need, acc} when need <= 0 ->
               {:halt, {need, acc}}

             %DB.TxOutput{amount: amount} = utxo, {need, acc} ->
               {:cont, {need - amount, [utxo | acc]}}
           end)

         utxo ->
           {0, [utxo]}
       end}
    end)
  end

  @doc """
  Sums up payable amount by token, including the fee.
  """
  @spec needed_funds(list(payment_t()), %{amount: pos_integer(), currency: currency_t()}) ::
          %{currency_t() => pos_integer()}
  def needed_funds(payments, %{currency: fee_currency, amount: fee_amount}) do
    needed_funds =
      payments
      |> Enum.group_by(fn payment -> payment.currency end)
      |> Stream.map(fn {token, payment} ->
        {token, payment |> Stream.map(fn payment -> payment.amount end) |> Enum.sum()}
      end)
      |> Map.new()

    Map.update(needed_funds, fee_currency, fee_amount, fn amount -> amount + fee_amount end)
  end

  @doc """
  Checks if the result of `select_utxos/2` covers the amount(s) of the transaction order.
  """
  @spec funds_sufficient([
          {currency :: currency_t(), {variance :: integer(), selected_utxos :: utxo_list_t()}}
        ]) ::
          {:ok, [{currency_t(), utxo_list_t()}]}
          | {:error, {:insufficient_funds, [%{token: String.t(), missing: pos_integer()}]}}
  def funds_sufficient(utxo_selection) do
    missing_funds =
      utxo_selection
      |> Stream.filter(fn {_currency, {variance, _selected_utxos}} -> variance > 0 end)
      |> Enum.map(fn {currency, {missing, _selected_utxos}} ->
        %{token: Encoding.to_hex(currency), missing: missing}
      end)

    case Enum.empty?(missing_funds) do
      true ->
        {:ok,
         utxo_selection
         |> Enum.reduce(%{}, fn {token, {_missing_amount, utxos}}, acc ->
           Map.put(acc, token, utxos)
         end)}

      _ ->
        {:error, {:insufficient_funds, missing_funds}}
    end
  end

  @spec filter_unselected(utxo_list_t(), %{currency_t() => boolean()}) :: utxo_list_t()
  defp filter_unselected(available_utxos, selected_utxo_hashes) do
    Enum.filter(available_utxos, fn utxo ->
      !Map.has_key?(selected_utxo_hashes, utxo.child_chain_utxohash)
    end)
  end

  @spec get_number_of_utxos(utxos_map_t()) :: integer()
  defp get_number_of_utxos(utxos_by_currency) do
    Enum.reduce(utxos_by_currency, 0, fn {_currency, utxos}, acc -> length(utxos) + acc end)
  end
end
