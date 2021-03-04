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

defmodule OMG.WatcherInfo.UtxoSelection do
  @moduledoc """
  Provides Utxos selection and merging algorithms.
  """

  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Watcher.State.Transaction
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.Transaction, as: TransactionCreator

  require Transaction
  require Transaction.Payment

  @type currency_t() :: Transaction.Payment.currency()
  @type utxos_map_t() :: %{currency_t() => utxo_list_t()}
  @type utxo_list_t() :: list(%DB.TxOutput{})

  @doc """
  Defines and prioritises available UTXOs for stealth merge based on the available and selected sets.
  - Excludes currencies not already used in the transaction and UTXOs in the selected set.
  - Prioritises currencies that have the largest number of UTXOs
  - Sorts by ascending order of UTXO value within the currency groupings ("dust first").
  """
  @spec prioritize_merge_utxos(utxos_map_t(), utxos_map_t()) :: utxo_list_t()
  def prioritize_merge_utxos(utxos, selected_utxos) do
    utxos_hash =
      selected_utxos
      |> Enum.flat_map(fn {_ccy, utxos} -> utxos end)
      |> Enum.reduce(%{}, fn utxo, acc -> Map.put(acc, utxo.child_chain_utxohash, true) end)

    case utxos_hash do
      hashes_map when map_size(hashes_map) == 0 ->
        []

      hashes_map ->
        selected_utxos
        |> Enum.map(&prioritize_utxos_by_currency(&1, utxos, hashes_map))
        |> Enum.sort_by(&length/1, :desc)
        |> Enum.map(fn currency_utxos -> currency_utxos |> Enum.slice(0, 3) |> Enum.reverse() end)
        |> Enum.reduce(fn utxos, acc -> utxos ++ acc end)
        |> Enum.reverse()
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

        stealth_merge_utxos =
          Map.update!(selected_utxos, priority_utxo.currency, fn current_utxos ->
            [priority_utxo | current_utxos]
          end)

        add_utxos_for_stealth_merge(remaining_available_utxos, stealth_merge_utxos)
    end
  end

  @doc """
  Given the available set of UTXOs and the net amount by currency, tries to find a UTXO that satisfies the payment with no change.
  If this fails, starts to collect UTXOs (starting from the largest amount) until the payment is covered.
  Returns {currency, { variance, [utxos] }}. A `variance` greater than zero means insufficient funds.
  The ordering of UTXOs in descending order of amount is implicitly assumed for this algorithm to work deterministically.
  """
  @spec select_utxos(%{currency_t() => pos_integer()}, utxos_map_t()) ::
          list({currency_t(), {integer, utxo_list_t()}})
  def select_utxos(net_amount, utxos) do
    Enum.map(net_amount, fn {token, need} ->
      selected_utxos =
        utxos
        |> Map.get(token, [])
        |> find_utxos_by_token(need)

      {token, selected_utxos}
    end)
  end

  @doc """
  Sums up payable amount by token, including the fee.
  """
  @spec calculate_net_amount(list(TransactionCreator.payment_t()), %{amount: pos_integer(), currency: currency_t()}) ::
          %{currency_t() => pos_integer()}
  def calculate_net_amount(payments, %{currency: fee_currency, amount: fee_amount}) do
    net_amount_map =
      payments
      |> Enum.group_by(fn payment -> payment.currency end)
      |> Stream.map(fn {token, payment} ->
        {token, payment |> Stream.map(fn payment -> payment.amount end) |> Enum.sum()}
      end)
      |> Map.new()

    Map.update(net_amount_map, fee_currency, fee_amount, fn amount -> amount + fee_amount end)
  end

  @doc """
  Checks if the result of `select_utxos/2` covers the amount(s) of the transaction order.
  """
  @spec review_selected_utxos([
          {currency :: currency_t(), {variance :: integer(), selected_utxos :: utxo_list_t()}}
        ]) ::
          {:ok, utxos_map_t()}
          | {:error, {:insufficient_funds, [%{token: String.t(), missing: pos_integer()}]}}
  def review_selected_utxos(utxo_selection) do
    missing_funds =
      utxo_selection
      |> Stream.filter(fn {_currency, {variance, _selected_utxos}} -> variance > 0 end)
      |> Enum.map(fn {currency, {missing, _selected_utxos}} ->
        %{token: Encoding.to_hex(currency), missing: missing}
      end)

    case Enum.empty?(missing_funds) do
      true ->
        {:ok,
         Enum.reduce(utxo_selection, %{}, fn {token, {_missing_amount, utxos}}, acc ->
           Map.put(acc, token, utxos)
         end)}

      _ ->
        {:error, {:insufficient_funds, missing_funds}}
    end
  end

  defp recursively_find_utxos(_, need, selected_utxos) when need <= 0, do: {need, selected_utxos}
  defp recursively_find_utxos([], need, _), do: {need, []}

  defp recursively_find_utxos([utxo | utxos], need, selected_utxos),
    do: recursively_find_utxos(utxos, need - utxo.amount, [utxo | selected_utxos])

  defp find_utxos_by_token(token_utxos, need) do
    case Enum.find(token_utxos, fn %DB.TxOutput{amount: amount} -> amount == need end) do
      nil ->
        recursively_find_utxos(token_utxos, need, [])

      utxo ->
        {0, [utxo]}
    end
  end

  defp prioritize_utxos_by_currency({currency, _utxos}, utxos, selected_utxo_hashes) do
    utxos[currency]
    |> filter_unselected(selected_utxo_hashes)
    |> Enum.sort_by(fn utxo -> utxo.amount end, :asc)
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
