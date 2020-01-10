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

defmodule OMG.Conformance.MerkleProofPropertyTest do
  @moduledoc """
  Checks if some properties about the merkle proofing (proof generation and validation) behaves consistently across
  implementations (currently `elixir-omg` and `plasma-contracts`, Elixir and Solidity)
  """

  alias OMG.Merkle
  alias Support.Conformance.MerkleProofContext
  alias Support.SnapshotContracts

  import Support.Conformance.MerkleProofs, only: [solidity_proof_valid: 5]

  use PropCheck
  use ExUnit.Case, async: false

  @moduletag :property
  @moduletag timeout: 450_000

  @proof_length 16
  @max_block_size trunc(:math.pow(2, @proof_length))

  setup_all do
    {:ok, exit_fn} = Support.DevNode.start()

    contracts = SnapshotContracts.parse_contracts()
    merkle_wrapper_address_hex = contracts["CONTRACT_ADDRESS_MERKLE_WRAPPER"]

    on_exit(fn ->
      exit_fn.()
    end)

    [contract: OMG.Eth.Encoding.from_hex(merkle_wrapper_address_hex)]
  end

  property "any root hash and proof created by the Elixir implementation validates in the contract, for all leaves",
           [250, :verbose, max_size: 256, constraint_tries: 100_000],
           %{contract: contract} do
    forall leaves <- list(binary()) do
      root_hash = Merkle.hash(leaves)

      leaves
      |> Enum.with_index()
      |> Enum.all?(fn {leaf, txindex} ->
        proof = Merkle.create_tx_proof(leaves, txindex)
        solidity_proof_valid(leaf, txindex, root_hash, proof, contract)
      end)
    end
  end

  property "no proof can prove a mutated leaf",
           [2500, :verbose, max_size: 256, constraint_tries: 100_000],
           %{contract: contract} do
    forall proof <- MerkleProofContext.correct() do
      forall mutated <- MerkleProofContext.mutated_leaf(proof) do
        if proof == mutated, do: IO.puts("equal")
        not solidity_proof_valid(mutated.leaf, mutated.txindex, mutated.root_hash, mutated.proof, contract)
      end
    end
  end

  property "no proof can prove at different index",
           [2500, :verbose, max_size: 256, constraint_tries: 100_000],
           %{contract: contract} do
    forall proof <- MerkleProofContext.correct() do
      forall mutated <- MerkleProofContext.mutated_txindex(proof) do
        if proof == mutated, do: IO.puts("equal")
        not solidity_proof_valid(mutated.leaf, mutated.txindex, mutated.root_hash, mutated.proof, contract)
      end
    end
  end

  property "no mutated proof bytes can prove anything that the original proved",
           [2500, :verbose, max_size: 256, constraint_tries: 100_000],
           %{contract: contract} do
    forall proof <- MerkleProofContext.correct() do
      forall mutated <- MerkleProofContext.mutated_proof(proof) do
        if proof == mutated, do: IO.puts("equal")
        not solidity_proof_valid(mutated.leaf, mutated.txindex, mutated.root_hash, mutated.proof, contract)
      end
    end
  end

  property "no proof can prove a different leaf/txindex if proof bytes mutated",
           [2500, :verbose, max_size: 256, constraint_tries: 100_000],
           %{contract: contract} do
    forall proof <- MerkleProofContext.correct() do
      forall mutated <- MerkleProofContext.mutated_to_prove_sth_else(proof) do
        if proof == mutated, do: IO.puts("equal")
        not solidity_proof_valid(mutated.leaf, mutated.txindex, mutated.root_hash, mutated.proof, contract)
      end
    end
  end

  # FIXME: full 2**16 merkle trees, >2**16 proofs and trees (?) - property test or not?
end
