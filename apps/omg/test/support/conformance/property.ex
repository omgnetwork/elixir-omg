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

defmodule Support.Conformance.PropertyGenerators do
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

  defp non_zero_address(), do: union([exactly(<<1::160>>), binary(20)])
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

  defp valid_blknum(), do: non_neg_integer()
  defp valid_txndex(), do: integer(0, 1_000_000_000 - 1)
  defp valid_oindex(), do: integer(0, 10_000 - 1)

  # TODO: revisit this to generate logic-wise invalid txs like zero inputs/outputs (H6)
  defp valid_input_tuple() do
    proposition_result =
      let [blknum <- valid_blknum(), txindex <- valid_txndex(), oindex <- valid_oindex()] do
        {blknum, txindex, oindex}
      end

    such_that({blknum, txindex, oindex} <- proposition_result, when: blknum + txindex + oindex > 0)
  end

  # TODO: revisit the case of negative amounts, funny things happen
  defp valid_output_tuple() do
    let [owner <- non_zero_address(), currency <- address(), amount <- pos_integer()] do
      {owner, currency, amount}
    end
  end

  defp valid_inputs_list() do
    such_that(l <- list(valid_input_tuple()), when: length(l) <= Transaction.Payment.max_inputs())
  end

  defp valid_outputs_list() do
    such_that(l <- list(valid_output_tuple()), when: length(l) > 0 && length(l) <= Transaction.Payment.max_outputs())
  end

  defp mutated_hash(base_hash) do
    # TODO: provide more cases
    OMG.Crypto.hash(base_hash)
  end

  defp mutated_inputs(inputs) do
    # TODO: provide more cases
    if Enum.empty?(inputs), do: valid_inputs_list(), else: tl(inputs)
  end

  defp mutated_outputs(outputs) do
    # TODO: provide more cases
    if length(outputs) == 1, do: valid_outputs_list(), else: tl(outputs)
  end

  # TODO: these mutations used could use improving/extending
  defp prepend_binary(base_binary) do
    let(random_binary <- injectable_binary(), do: random_binary <> base_binary)
  end

  # TODO: these mutations used could use improving/extending
  defp apend_binary(base_binary) do
    let(random_binary <- injectable_binary(), do: base_binary <> random_binary)
  end

  # TODO: these mutations used could use improving/extending
  defp substring_binary(base_binary) do
    base_length = byte_size(base_binary)

    let [from <- integer(0, base_length - 1)] do
      max_substring_length = max(1, base_length - from)

      let [substring_length <- integer(1, max_substring_length)] do
        binary_part(base_binary, from, substring_length)
      end
    end
  end

  # TODO: these mutations used could use improving/extending
  defp insert_into_binary(base_binary) do
    base_length = byte_size(base_binary)

    let [from <- integer(0, base_length - 1), random_binary <- injectable_binary()] do
      binary_part(base_binary, 0, from) <> random_binary <> binary_part(base_binary, from, base_length - from)
    end
  end

  defp mutate_binary(base_binary) do
    # TODO: these mutations used could use improving/extending
    # TODO: example case - cut off one byte somewhere (beginning, end, middle) - more specifically wrt. "substring" etc
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
      # TODO for now we only mutate deepest level of the RLP items. Mutate also intermediate levels
      let([mutated_rlp <- mutate_sub_rlp(to_mutate)], do: List.replace_at(rlp_items, index, mutated_rlp))
    end
  end

  defp mutate_sub_rlp(rlp_item) when is_integer(rlp_item) or is_binary(rlp_item), do: rlp_item_generator()

  defp rlp_item_generator(),
    do: union([[], injectable_binary(), non_neg_integer(), list(union([injectable_binary(), non_neg_integer()]))])

  defp rlp_mutate_binary(base_binary) do
    # TODO: these mutations used could use improving/extending
    base_rlp_items = base_binary |> Transaction.decode!() |> Transaction.Protocol.get_data_for_rlp()

    union([
      inject_extra_item(base_rlp_items),
      recursively_mutate_rlp(base_rlp_items)
    ])
  end
end
