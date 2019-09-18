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
  @moduledoc """
  module supports transaction modification in such a way that it will still be possible send ife
  """

  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  @spec mutate(binary | Transaction.Recovered.t(), %{Utxo.Position.t() => binary}, %{binary => binary}) :: any()
  def mutate(tx, map_position_owners, map_users) when is_binary(tx) do
    mutate(Transaction.Recovered.recover_from!(tx), map_position_owners, map_users)
  end

  def mutate(
        %Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: raw_tx}} = recovered_tx,
        map_position_owners,
        map_users,
        {probability_remove, probability_add, probability_change_value, probability_order} \\ {10, 20, 30, 50}
      ) do
    mutated_tx =
      raw_tx
      |> (fn tx -> apply_with_probability(probability_remove, &mutate_remove/1, [tx]) end).()
      |> (fn tx -> apply_with_probability(probability_add, &mutate_add/2, [tx, map_position_owners]) end).()
      |> (fn tx -> apply_with_probability(probability_change_value, &mutate_change_value/1, [tx]) end).()
      |> (fn tx -> apply_with_probability(probability_order, &mutate_order/1, [tx]) end).()

    if mutated_tx == raw_tx,
      do: mutate(recovered_tx, map_position_owners, map_users),
      else: sign(mutated_tx, recovered_tx, map_position_owners, map_users)
  end

  defp apply_with_probability(percent, function, [tx | _] = args) do
    if :rand.uniform(100) <= percent,
      do: apply(function, args),
      else: tx
  end

  defp mutate_order(tx) do
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

  defp mutate_remove(tx) do
    outputs = Transaction.get_outputs(tx) |> payment_output()
    # we can try to remove at lenght which does not change a list
    outputs = outputs |> List.delete_at(:rand.uniform(length(outputs) + 1) - 1)

    metadata =
      if Enum.random([true, false]),
        do: tx.metadata,
        else: nil

    inputs = Transaction.get_inputs(tx) |> payment_input()

    Transaction.Payment.new(inputs, outputs, metadata)
  end

  defp mutate_change_value(tx) do
    outputs = Transaction.get_outputs(tx)
    random_position = :rand.uniform(length(outputs) + 1) - 1
    random_modification = Enum.random(1..10)

    outputs =
      List.update_at(outputs, random_position, fn %{amount: amount} = output ->
        %{output | amount: max(0, amount - random_modification)}
      end)
      |> payment_output

    Transaction.Payment.new(Transaction.get_inputs(tx) |> payment_input, outputs, tx.metadata)
  end

  defp mutate_add(tx, map_position_owners) do
    input = Transaction.get_inputs(tx)
    outputs = Transaction.get_outputs(tx)
    metadata = tx.metadata

    metadata =
      if !metadata and Enum.random([true, false]),
        do: random_binary(32),
        else: metadata

    input =
      if Enum.random([true, false]) do
        new_position =
          map_position_owners
          |> Map.keys()
          |> Enum.random()

        [new_position | input]
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

  defp random_binary(size) do
    for _ <- 1..size, into: <<>>, do: <<:rand.uniform(256)>>
  end

  defp sign(raw_tx, recovered_tx, map_position_owners, map_users) do
    map_position_owners_from_recovered_tx =
      Transaction.get_inputs(recovered_tx)
      |> Enum.with_index()
      |> Enum.map(fn {position, index} ->
        owner = recovered_tx.witnesses[index]
        priv_key = Map.get(map_users, owner)
        {position, priv_key}
      end)
      |> Map.new()

    privs =
      Transaction.get_inputs(raw_tx)
      |> Enum.map(fn position ->
        owner = Map.get(map_position_owners, position)

        if owner == nil,
          do: Map.get(map_position_owners_from_recovered_tx, position),
          else: owner
      end)

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
