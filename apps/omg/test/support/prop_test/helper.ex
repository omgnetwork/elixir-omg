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

defmodule OMG.PropTest.Helper do
  @moduledoc """
  Common helper functions that are useful when propCheck testing
  """
  alias OMG.PropTest.Constants
  alias OMG.State.Transaction
  alias OMG.Utxo
  require Constants
  require Utxo

  @doc """
  Collapse of the recover transaction into a short form use in OMG.PropTest
  """
  def format_transaction(%Transaction.Recovered{
        signed_tx: %Transaction.Signed{
          raw_tx: raw_tx
        },
        spenders: [spender1, spender2]
      }) do
    inputs = Transaction.get_inputs(raw_tx)
    outputs = Transaction.get_outputs(raw_tx)

    [%{blknum: blknum1, txindex: txindex1, oindex: oindex1}, %{blknum: blknum2, txindex: txindex2, oindex: oindex2}] =
      inputs

    [%{owner: newowner1, currency: cur12, amount: amount1}, %{owner: newowner2, currency: cur12, amount: amount2}] =
      outputs

    {
      [
        {Utxo.position(blknum1, txindex1, oindex1), addr_to_owner_name(spender1)},
        {Utxo.position(blknum2, txindex2, oindex2), addr_to_owner_name(spender2)}
      ]
      |> Enum.filter(fn {_, spender} -> spender != nil end),
      currency_to_atom(cur12),
      [{addr_to_owner_name(newowner1), amount1}, {addr_to_owner_name(newowner2), amount2}]
      |> Enum.filter(fn {owner, _} -> owner != nil end)
    }
  end

  @doc """
  Collapse deposits list into a short form use in OMG.PropTest
  """
  def format_deposits(deposits) do
    Enum.map(deposits, fn %{amount: amount, blknum: blknum, currency: currency, owner: owner} ->
      {amount, currency_to_atom(currency), addr_to_owner_name(owner), blknum}
    end)
  end

  def get_addr(owner), do: OMG.TestHelper.entities_stable()[owner].addr

  @spec addr_to_owner_name(OMG.Crypto.priv_key_t() | OMG.Crypto.pub_key_t()) :: atom()
  def addr_to_owner_name(addr) do
    entities = OMG.TestHelper.entities_stable()

    case Enum.find(entities, fn element ->
           match?({_, %{addr: ^addr}}, element) or match?({_, %{priv: ^addr}}, element)
         end) do
      {owner_atom, _owner} -> owner_atom
      nil -> nil
    end
  end

  def currency_to_atom(addr) do
    Constants.currencies() |> Enum.find(&match?({_, ^addr}, &1)) |> elem(0)
  end

  def get_utxos(history) do
    history = Enum.reverse(history)
    get_utxos(history, {%{}, %{}}, {1_000, 0})
  end

  defp get_utxos([{:deposits, deposits} | history], {unspent, spent}, position) do
    new_unspent =
      deposits
      |> Enum.map(fn {amount, currency, owner, blknum} ->
        {Utxo.position(blknum, 0, 0), %{currency: currency, owner: owner, amount: amount}}
      end)
      |> Map.new()
      |> Map.merge(unspent)

    get_utxos(history, {new_unspent, spent}, position)
  end

  defp get_utxos([{:form_block, _} | history], utxos, {blknum, _tx_index}),
    do: get_utxos(history, utxos, {blknum + 1_000, 0})

  defp get_utxos([{:exit, utxo} | history], {unspent, spent}, {blknum, tx_index}),
    do:
      get_utxos(
        history,
        {Map.drop(unspent, utxo), Enum.reduce(utxo, spent, &Map.put_new(&2, &1, Map.get(unspent, &1)))},
        {blknum, tx_index}
      )

  defp get_utxos([{:everyone_exit, _} | history], {unspent, spent}, {blknum, tx_index}),
    do: get_utxos(history, {%{}, Map.merge(unspent, spent)}, {blknum, tx_index})

  defp get_utxos([{:transaction, {inputs, currency, output}} | history], {unspent, spent}, {blknum, tx_index}) do
    keys_to_remove = inputs |> Enum.map(&elem(&1, 0))

    new_utxo =
      output
      |> Enum.with_index()
      |> Enum.map(fn {{owner, amount}, oindex} ->
        {Utxo.position(blknum, tx_index, oindex), %{amount: amount, currency: currency, owner: owner}}
      end)
      |> Map.new()

    {spent_in_transaction, unspent} = Map.split(unspent, keys_to_remove)
    get_utxos(history, {Map.merge(unspent, new_utxo), Map.merge(spent, spent_in_transaction)}, {blknum, tx_index + 1})
  end

  defp get_utxos([_ | history], utxos, position), do: get_utxos(history, utxos, position)
  defp get_utxos([], utxos, {_blknum, _tx_index}), do: utxos

  def spendable(history), do: elem(get_utxos(history), 0)

  @doc """
  create AST delegate function to ```module``` use in [defcommand](https://hexdocs.pm/propcheck/PropCheck.StateM.DSL.html#defcommand/2)
  """
  def create_delegate_to_defcommand(module) do
    module.__info__(:functions)
    |> Enum.filter(&(&1 in [pre: 2, next: 3, post: 3, args: 1] or match?({:impl, _}, &1)))
    |> Enum.uniq()
    |> Enum.map(&create_ast_function(module, &1))
  end

  defp create_ast_function(module, {name, arity}) do
    args =
      Enum.to_list(0..arity)
      |> tl
      |> Enum.map(fn number -> {String.to_atom("value_" <> Integer.to_string(number)), [], :"Elixir"} end)

    {:def, [import: Kernel],
     [{name, [], args}, [do: {{:., [], [{:__aliases__, [alias: false], module}, name]}, [], args}]]}
  end
end
