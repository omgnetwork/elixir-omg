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

defmodule Support.Conformance.Property do
  @moduledoc """
  Utility functions (mainly `:propcheck` generators) useful for building property tests for conformance tests
  """

  alias OMG.State.Transaction

  use PropCheck

  require Transaction.Payment

  def payment_tx() do
    let [inputs <- valid_inputs_list(), outputs <- valid_outputs_list(), metadata <- hash()] do
      Transaction.Payment.new(inputs, outputs, metadata)
    end
  end

  def distinct_payment_txs() do
    proposition_result =
      let [inputs <- valid_inputs_list(), outputs <- valid_outputs_list(), metadata <- hash()] do
        tx1 = Transaction.Payment.new(inputs, outputs, metadata)

        tx2 =
          let [
            inputs2 <- union([inputs, mutated_inputs(inputs)]),
            outputs2 <- union([outputs, mutated_outputs(outputs)]),
            metadata2 <- union([metadata, mutated_hash(metadata)])
          ] do
            Transaction.Payment.new(inputs2, outputs2, metadata2)
          end

        {tx1, tx2}
      end

    such_that(pair <- proposition_result, when: is_pair_of_distinct_terms?(pair))
  end

  def tx_binary_with_mutation() do
    proposition_result =
      let [tx1 <- payment_tx()] do
        tx1_binary = Transaction.raw_txbytes(tx1)
        {tx1_binary, mutate_binary(tx1_binary)}
      end

    such_that(pair <- proposition_result, when: is_pair_of_distinct_terms?(pair))
  end

  def tx_binary_with_rlp_mutation() do
    proposition_result =
      let [tx1 <- payment_tx()] do
        tx1_binary = Transaction.raw_txbytes(tx1)
        {tx1_binary, rlp_mutate_binary(tx1_binary)}
      end

    such_that(pair <- proposition_result, when: is_pair_of_distinct_terms?(pair))
  end

  defp is_pair_of_distinct_terms?({base_term, new_term}), do: base_term != new_term

  defp address(), do: union([exactly(<<0::160>>), exactly(<<1::160>>), binary(20)])
  defp hash(), do: union([exactly(<<0::256>>), exactly(<<1::256>>), binary(32)])

  defp injectable_binary() do
    union([
      binary(),
      <<0::8>>,
      <<1::8>>,
      <<0::16>>,
      <<1::16>>,
      <<0::32>>,
      <<1::32>>,
      <<0::128>>,
      <<1::128>>,
      <<0::256>>,
      <<1::256>>
    ])
  end

  # FIXME: revisit zero inputs, as funny things happen in the test:
  #        "any rlp-mutated tx binary either fails to decode to a transaction object or is recognized as different"
  #        it fails, because the generator generates zero utxo positions, which Utxo.Position.decode! prohibits
  defp input_tuple() do
    let [blknum <- pos_integer(), txindex <- non_neg_integer(), oindex <- non_neg_integer()] do
      {blknum, txindex, oindex}
    end
  end

  # FIXME: revisit non_neg_integer amount in a different test case
  # FIXME: revisit the case of negative amounts, funny things happen
  defp output_tuple() do
    let [owner <- address(), currency <- address(), amount <- pos_integer()] do
      {owner, currency, amount}
    end
  end

  defp valid_inputs_list(),
    do: such_that(l <- list(input_tuple()), when: length(l) <= Transaction.Payment.max_inputs())

  defp valid_outputs_list(),
    do: such_that(l <- list(output_tuple()), when: length(l) <= Transaction.Payment.max_outputs())

  defp mutated_hash(base_hash) do
    # FIXME: provide more cases
    OMG.Crypto.hash(base_hash)
  end

  defp mutated_inputs(inputs) do
    # FIXME: provide more cases
    if Enum.empty?(inputs), do: valid_inputs_list(), else: tl(inputs)
  end

  defp mutated_outputs(outputs) do
    # FIXME: provide more cases
    if Enum.empty?(outputs), do: valid_outputs_list(), else: tl(outputs)
  end

  # FIXME: these mutations used could use improving/extending
  defp prepend_binary(base_binary) do
    let(random_binary <- injectable_binary(), do: random_binary <> base_binary)
  end

  # FIXME: these mutations used could use improving/extending
  defp apend_binary(base_binary) do
    let(random_binary <- injectable_binary(), do: base_binary <> random_binary)
  end

  # FIXME: these mutations used could use improving/extending
  defp substring_binary(base_binary) do
    base_length = byte_size(base_binary)

    let [from <- integer(0, base_length - 1)] do
      max_substring_length = max(1, base_length - from)

      let [substring_length <- integer(1, max_substring_length)] do
        binary_part(base_binary, from, substring_length)
      end
    end
  end

  # FIXME: these mutations used could use improving/extending
  defp insert_into_binary(base_binary) do
    base_length = byte_size(base_binary)

    let [from <- integer(0, base_length - 1), random_binary <- injectable_binary()] do
      binary_part(base_binary, 0, from) <> random_binary <> binary_part(base_binary, from, base_length - from)
    end
  end

  defp mutate_binary(base_binary) do
    # FIXME: these mutations used could use improving/extending
    union([
      prepend_binary(base_binary),
      apend_binary(base_binary),
      substring_binary(base_binary),
      insert_into_binary(base_binary)
    ])
  end

  defp inject_extra_item(base_rlp_items) do
    rlp_items_length = length(base_rlp_items)

    let [new_item <- rlp_item_generator(), index <- integer(0, rlp_items_length)] do
      base_rlp_items
      |> List.insert_at(index, new_item)
      |> ExRLP.encode()
    end
  end

  defp recursively_mutate_rlp(base_rlp_items) do
    let([mutated_rlp <- mutate_sub_rlp(base_rlp_items)], do: ExRLP.encode(mutated_rlp))
  end

  defp mutate_sub_rlp([]), do: rlp_item_generator()

  defp mutate_sub_rlp(rlp_items) when is_list(rlp_items) do
    rlp_items_length = length(rlp_items)

    let [index <- integer(0, rlp_items_length - 1)] do
      to_mutate = Enum.at(rlp_items, index)
      let([mutated_rlp <- mutate_sub_rlp(to_mutate)], do: List.replace_at(rlp_items, index, mutated_rlp))
    end
  end

  defp mutate_sub_rlp(rlp_item) when is_integer(rlp_item) or is_binary(rlp_item), do: rlp_item_generator()

  defp rlp_item_generator(),
    do: union([injectable_binary(), non_neg_integer(), list(union([injectable_binary(), non_neg_integer()]))])

  defp rlp_mutate_binary(base_binary) do
    # FIXME: these mutations used could use improving/extending
    base_rlp_items = base_binary |> Transaction.decode!() |> Transaction.Protocol.get_data_for_rlp()

    union([
      # FIXME: reenable or move to a different property?
      # inject_extra_item(base_rlp_items)
      recursively_mutate_rlp(base_rlp_items)
    ])
  end
end
