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

defmodule OMG.API.State.PropTest.Helper do
  @moduledoc """
  Helpers for in propCheck test
  """
  alias OMG.API.State.Transaction

  def format_transaction(%Transaction.Recovered{
        signed_tx: %Transaction.Signed{
          raw_tx: %Transaction{
            amount1: amount1,
            amount2: amount2,
            blknum1: blknum1,
            blknum2: blknum2,
            cur12: cur12,
            newowner1: newowner1,
            newowner2: newowner2,
            oindex1: oindex1,
            oindex2: oindex2,
            txindex1: txindex1,
            txindex2: txindex2
          }
        },
        spender1: spender1,
        spender2: spender2
      }) do
    {
      [
        {{blknum1, txindex1, oindex1}, addr_to_owner_name(spender1)},
        {{blknum2, txindex2, oindex2}, addr_to_owner_name(spender2)}
      ]
      |> Enum.filter(fn {_, spender} -> spender != nil end),
      currency_to_atom(cur12),
      [{addr_to_owner_name(newowner1), amount1}, {addr_to_owner_name(newowner2), amount2}]
      |> Enum.filter(fn {owner, _} -> owner != nil end)
    }
  end

  def format_deposits(deposits) do
    Enum.map(deposits, fn %{amount: amount, blknum: blknum, currency: currency, owner: owner} ->
      {amount, currency_to_atom(currency), addr_to_owner_name(owner), blknum}
    end)
  end

  def get_addr(owner), do: OMG.API.TestHelper.entities_stable()[owner].addr

  def addr_to_owner_name(addr) do
    entities = OMG.API.TestHelper.entities_stable()

    case Enum.find(entities, fn element ->
           match?({_, %{addr: ^addr}}, element) or match?({_, %{priv: ^addr}}, element)
         end) do
      {owner_atom, _owner} -> owner_atom
      nil -> nil
    end
  end

  def currency_to_atom(addr) do
    currency() |> Enum.find(&match?({_, ^addr}, &1)) |> elem(0)
  end

  def currency, do: %{ethereum: <<0::160>>, other: <<1::160>>}

  def spendable(history) do
    history = Enum.reverse(history)
    spendable(history, %{}, {1_000, 0})
  end

  defp spendable([{:deposits, deposits} | history], unspent, position) do
    new_unspent =
      deposits
      |> Enum.map(fn {amount, currency, owner, blknum} ->
        {{blknum, 0, 0}, %{currency: currency, owner: owner, amount: amount}}
      end)
      |> Map.new()
      |> Map.merge(unspent)

    spendable(history, new_unspent, position)
  end

  defp spendable([{:form_block, _} | history], unspent, {blknum, _tx_index}),
    do: spendable(history, unspent, {blknum + 1_000, 0})

  defp spendable([{:exit, utxo} | history], unspent, {blknum, tx_index}),
    do: spendable(history, Map.drop(unspent, utxo), {blknum, tx_index})

  defp spendable([{:everyone_exit, _} | history], _, {blknum, tx_index}),
    do: spendable(history, %{}, {blknum, tx_index})

  defp spendable([{:transaction, {inputs, currency, output}} | history], unspent, {blknum, tx_index}) do
    keys_to_remove = inputs |> Enum.map(&elem(&1, 0))

    new_utxo =
      output
      |> Enum.with_index()
      |> Enum.map(fn {{owner, amount}, oindex} ->
        {{blknum, tx_index, oindex}, %{amount: amount, currency: currency, owner: owner}}
      end)
      |> Map.new()

    unspent = Map.drop(unspent, keys_to_remove)
    unspent = Map.merge(unspent, new_utxo)

    spendable(history, unspent, {blknum, tx_index + 1})
  end

  defp spendable([], unspent, {_blknum, _tx_index}) do
    unspent
  end
end
