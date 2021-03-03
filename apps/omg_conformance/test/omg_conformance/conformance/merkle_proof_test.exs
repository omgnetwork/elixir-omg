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

defmodule OMG.Conformance.MerkleProofTest do
  @moduledoc """
  Checks if some particular cases of merkle proofs (proof generation and validation) behave consistently across
  implementations (currently `elixir-omg` and `plasma-contracts`, Elixir and Solidity)
  """

  alias OMG.Eth.Encoding
  alias OMG.Watcher.Crypto
  alias OMG.Watcher.Merkle
  alias Support.SnapshotContracts

  import Support.Conformance.MerkleProofs, only: [solidity_proof_valid: 5]

  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :common

  @proof_length 16
  @max_block_size trunc(:math.pow(2, @proof_length))

  setup_all do
    {:ok, exit_fn} = Support.DevNode.start()

    contracts = SnapshotContracts.parse_contracts()
    merkle_wrapper_address_hex = contracts["CONTRACT_ADDRESS_MERKLE_WRAPPER"]

    on_exit(exit_fn)

    [contract: Encoding.from_hex(merkle_wrapper_address_hex)]
  end

  test "a simple, 3-leaf merkle proof validates fine", %{contract: contract} do
    leaves = [<<1>>, <<0>>, <<>>]
    root_hash = Merkle.hash(leaves)

    leaves
    |> Enum.with_index()
    |> Enum.each(fn {leaf, txindex} ->
      proof = Merkle.create_tx_proof(leaves, txindex)
      assert solidity_proof_valid(leaf, txindex, root_hash, proof, contract)
    end)
  end

  @tag timeout: 240_000
  test "a full-tree merkle proof validates fine", %{contract: contract} do
    # why?
    # 1. we'd like to test all proofs on a full tree
    # 2. that's 65K proofs
    # 3. so we're pre-building the merkle tree by using raw `MerkleTree` calls instead of `OMG.Watcher.Merkle`
    #    This is slightly inconsistent, but otherwise the test takes forever
    full_leaves = Enum.map(1..@max_block_size, &:binary.encode_unsigned/1)
    full_root_hash = Merkle.hash(full_leaves)

    full_tree =
      MerkleTree.build(full_leaves,
        hash_function: &Crypto.hash/1,
        height: 16,
        default_data_block: <<0::256>>
      )

    full_leaves
    |> Enum.with_index()
    |> Enum.each(fn {leaf, txindex} ->
      proof = full_tree |> MerkleTree.Proof.prove(txindex) |> Enum.reverse() |> Enum.join()
      assert solidity_proof_valid(leaf, txindex, full_root_hash, proof, contract)
    end)
  end
end
