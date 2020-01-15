# Copyright 2020 OmiseGO Pte Ltd
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

defmodule Support.Conformance.MerkleProofContext do
  @moduledoc """
  A package of data associated with a single proof to assert about. Contains the proof, what it proves, and the under-
  -lying merkle tree leaves as well
  """
  defstruct [:leaves, :root_hash, :leaf, :txindex, :proof]

  alias OMG.Merkle

  use PropCheck

  def correct() do
    let leaves <- such_that(leaves <- list(binary()), when: length(leaves) > 0) do
      leaves_length = length(leaves)
      root_hash = Merkle.hash(leaves)

      let txindex <- integer(0, leaves_length - 1) do
        proof = Merkle.create_tx_proof(leaves, txindex)
        leaf = Enum.at(leaves, txindex)
        %__MODULE__{leaves: leaves, root_hash: root_hash, leaf: leaf, txindex: txindex, proof: proof}
      end
    end
  end

  def mutated_leaf(%__MODULE__{} = base) do
    # TODO: add borrowing leaf from proof

    # Some of the generators under `union/1` are only valid on certain conditions. Setting weight to 0 prevents them
    # if the condition is not met
    zero_out_leaf_weight = if base.leaf == <<0::256>>, do: 0, else: 1
    trimmed_leaf_weight = if base.leaf == "", do: 0, else: 1
    get_other_leaf_weight = if base.leaves |> Enum.uniq() |> length() < 2, do: 0, else: 1

    weighted_union([
      {zero_out_leaf_weight, zero_out_leaf(base)},
      {1, random_leaf(base)},
      {trimmed_leaf_weight, trimmed_leaf(base)},
      {1, expanded_leaf(base)},
      {get_other_leaf_weight, get_other_leaf(base)}
    ])
  end

  def mutated_txindex(%__MODULE__{} = base) do
    # The trick here is that it can be any index (even beyond the scope of leaves list!), but can't point to an
    # identical leaf, in case we have 2 in the leaves list.
    # So this is slightly different from `distinct_leaf_index` in `get_other_leaf/1`
    distinct_leaf_index = such_that(i <- non_neg_integer(), when: Enum.at(base.leaves, i) != base.leaf)

    let other_txindex <- distinct_leaf_index do
      %{base | txindex: other_txindex}
    end
  end

  def mutated_proof(%__MODULE__{} = base) do
    union([
      bitwise_modify(base),
      chunkwise_modify(base)
    ])
  end

  def mutated_to_prove_sth_else(%__MODULE__{} = base) do
    let should_mutate_the_leaf <- boolean() do
      let [
        other_proof <- mutated_proof(base),
        proving_something_else <- if(should_mutate_the_leaf, do: mutated_leaf(base), else: mutated_txindex(base))
      ] do
        %{proving_something_else | proof: other_proof.proof}
      end
    end
  end

  defp chunkwise_modify(%__MODULE__{} = base) do
    insert_leaf_chunk_weight = if base.leaf == "", do: 0, else: 1

    weighted_union([
      {1, insert_zero_chunk(base)},
      {insert_leaf_chunk_weight, insert_leaf_chunk(base)},
      {1, drop_chunk(base)},
      {1, swap_neighbors(base)}
    ])
  end

  defp insert_zero_chunk(%__MODULE__{} = base) do
    # @proof length doesn't work for some reason
    let position <- integer(0, 16) do
      %{base | proof: base.proof |> chunk() |> List.insert_at(position, <<0::256>>) |> unchunk()}
    end
  end

  defp insert_leaf_chunk(%__MODULE__{} = base) do
    # @proof length doesn't work for some reason
    let position <- integer(0, 16) do
      %{base | proof: base.proof |> chunk() |> List.insert_at(position, base.leaf) |> unchunk()}
    end
  end

  defp drop_chunk(%__MODULE__{} = base) do
    # @proof length doesn't work for some reason
    let position <- integer(0, 16 - 1) do
      %{base | proof: base.proof |> chunk() |> List.delete_at(position) |> unchunk()}
    end
  end

  defp swap_neighbors(%__MODULE__{} = base) do
    # @proof length doesn't work for some reason
    let position <- integer(0, 16 - 1 - 1) do
      chunked_proof = chunk(base.proof)
      [neighbor1, neighbor2] = Enum.slice(chunked_proof, position, 2)

      swapped_proof =
        chunked_proof
        |> List.replace_at(position, neighbor2)
        |> List.replace_at(position + 1, neighbor1)
        |> unchunk

      %{base | proof: swapped_proof}
    end
  end

  defp bitwise_modify(%__MODULE__{} = base) do
    # FIXME: more cases of these (expand appending/trimming just like with the leaf)
    union([
      bitwise_append(base)
    ])
  end

  defp bitwise_append(%__MODULE__{} = base) do
    let to_append <- union([non_empty_binary(), <<0>>, <<0::256>>, <<0::512>>]) do
      %{base | proof: base.proof <> to_append}
    end
  end

  defp zero_out_leaf(%__MODULE__{} = base) do
    %{base | leaf: <<0::256>>}
  end

  defp random_leaf(%__MODULE__{} = base) do
    let b <- such_that(b <- binary(), when: b != base.leaf) do
      %{base | leaf: b}
    end
  end

  defp trimmed_leaf(%__MODULE__{} = base) do
    length_leaf = byte_size(base.leaf)

    let to_keep <- integer(0, length_leaf - 1) do
      %{base | leaf: binary_part(base.leaf, 0, to_keep)}
    end
  end

  defp expanded_leaf(%__MODULE__{} = base) do
    let [b <- non_empty_binary(), append? <- boolean()] do
      if append?, do: %{base | leaf: base.leaf <> b}, else: %{base | leaf: b <> base.leaf}
    end
  end

  defp get_other_leaf(%__MODULE__{} = base) do
    length_leaves = length(base.leaves)
    distinct_leaf_index = such_that(i <- integer(0, length_leaves - 1), when: Enum.at(base.leaves, i) != base.leaf)

    let other_index <- distinct_leaf_index do
      %{base | leaf: Enum.at(base.leaves, other_index)}
    end
  end

  defp non_empty_binary(), do: such_that(b <- binary(), when: b != "")

  #
  # auxiliary helper functions

  defp chunk(proof), do: for(<<chunk::256 <- proof>>, do: <<chunk::256>>)
  defp unchunk(chunked_proof), do: Enum.join(chunked_proof)
end
