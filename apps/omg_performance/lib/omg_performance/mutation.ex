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

defmodule OMG.Performance.ByzantineEvents.Mutation do
  @moduledoc false

  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  def mutation_tx(tx, utxos, users) when is_binary(tx) do
    mutation_tx(Transaction.Recovered.recover_from!(tx), utxos, users)
  end

  def mutation_tx(
        recovered_tx,
        utxos,
        users,
        {probability_remove, probability_add, probability_change_value, probability_order} \\ {10, 20, 30, 50}
      ) do
    mutated_tx =
      recovered_tx.signed_tx.raw_tx
      |> (fn tx -> apply_with_probability(probability_remove, &mutate_remove/1, [tx]) end).()
      |> (fn tx -> apply_with_probability(probability_add, &mutate_add/2, [tx, utxos]) end).()
      |> (fn tx -> apply_with_probability(probability_change_value, &mutate_change_value/1, [tx]) end).()
      |> (fn tx -> apply_with_probability(probability_order, &mutate_order/1, [tx]) end).()

    if mutated_tx == recovered_tx.signed_tx.raw_tx,
      do: mutation_tx(recovered_tx, utxos, users),
      else: sign(mutated_tx, recovered_tx, utxos, users)
  end

  def apply_with_probability(percent, function, args) do
    if :random.uniform(100) <= percent,
      do: apply(function, args),
      else: hd(args)
  end

  def mutate_order(tx) do
    inputs =
      Transaction.get_inputs(tx)
      |> Enum.shuffle()
      |> payment_input()

    outputs =
      Transaction.get_outputs(tx)
      |> Enum.shuffle()
      |> payment_output()

    Transaction.Payment.new(inputs, outputs, tx.metadata)
  end

  def mutate_remove(tx) do
    inputs = Transaction.get_inputs(tx) |> payment_input()
    # inputs = inputs |> List.delete_at(:random.uniform(length(inputs) + 1) - 1)
    outputs = Transaction.get_outputs(tx) |> payment_output()
    outputs = outputs |> List.delete_at(:random.uniform(length(outputs) + 1) - 1)

    metadata =
      if Enum.random([true, false]),
        do: tx.metadata,
        else: nil

    Transaction.Payment.new(inputs, outputs, metadata)
  end

  def mutate_change_value(tx) do
    outputs = Transaction.get_outputs(tx)
    random_position = :random.uniform(length(outputs)) - 1
    random_modification = Enum.random(0..10)

    outputs =
      List.update_at(outputs, random_position, fn %{amount: amount} = output ->
        %{output | amount: max(0, amount - random_modification)}
      end)
      |> payment_output

    Transaction.Payment.new(Transaction.get_inputs(tx) |> payment_input, outputs, tx.metadata)
  end

  def mutate_add(tx, utxos) do
    input = Transaction.get_inputs(tx)
    outputs = Transaction.get_outputs(tx)
    metadata = tx.metadata

    metadata =
      if !metadata and Enum.random([true, false]),
        do: random_binary(32),
        else: metadata

    input =
      if Enum.random([true, false]) do
        %{blknum: blknum, txindex: txindex, oindex: oindex} = Enum.random(utxos)
        [Utxo.position(blknum, txindex, oindex) | input]
      else
        input
      end

    outputs =
      if Enum.random([true, false]),
        do: [
          %{
            amount: 0,
            currency: random_binary(20),
            owner: random_binary(20)
          }
          | outputs
        ],
        else: outputs

    Transaction.Payment.new(input |> payment_input, outputs |> payment_output, metadata)
  end

  def random_binary(size) do
    for _ <- 1..size, into: <<>>, do: <<:random.uniform(256)>>
  end

  def sign(raw_tx, recovered_tx, utxos, users) do
    map_owners =
      [
        utxos
        |> Enum.map(fn %{blknum: blknum, txindex: txindex, oindex: oindex, owner: owner} ->
          {Utxo.position(blknum, txindex, oindex), OMG.Eth.Encoding.from_hex(owner)}
        end),
        Transaction.get_inputs(recovered_tx)
        |> Enum.with_index()
        |> Enum.map(fn {position, index} ->
          {position, recovered_tx.witnesses[index]}
        end)
      ]
      |> Enum.concat()
      |> Enum.map(fn {position, owner} ->
        owner = Enum.find(users, fn %{addr: addr} -> addr == owner end)

        case owner do
          %{priv: priv_key} -> {position, priv_key}
          _ -> {position, nil}
        end
      end)
      |> Map.new()

    privs = Transaction.get_inputs(raw_tx) |> Enum.map(fn utxo -> Map.get(map_owners, utxo) end)

    if Enum.any?(privs, &(&1 == nil)),
      do: {:error, :cant_sign},
      else: {:ok, OMG.DevCrypto.sign(raw_tx, privs)}
  end

  defp payment_input(input) do
    Enum.map(input, fn Utxo.position(blknum, txindex, oindex) -> {blknum, txindex, oindex} end)
  end

  defp payment_output(output) do
    Enum.map(output, fn %{amount: amount, currency: currency, owner: owner} -> {owner, currency, amount} end)
  end
end
