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

  # FIXME: explicit import here
  import Support.Conformance.MerkleProofs

  use PropCheck
  use ExUnit.Case, async: false

  @moduletag :property
  @moduletag timeout: 450_000

  @max_block_size trunc(:math.pow(2, 16))

  setup_all do
    {:ok, exit_fn} = Support.DevNode.start()

    contracts = parse_contracts()
    merkle_wrapper_address_hex = contracts["CONTRACT_ADDRESS_MERKLE_WRAPPER"]

    on_exit(fn ->
      exit_fn.()
    end)

    [contract: OMG.Eth.Encoding.from_hex(merkle_wrapper_address_hex)]
  end

  property "any root hash and proof created by the Elixir implementation validates in the contract",
           # FIXME: revisit max sizes and num tests in all tests
           [50, :verbose, max_size: @max_block_size, constraint_tries: 100_000],
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

  # FIXME: remove work tag
  @tag :work
  property "no proof created by the Elixir implementation proves a different txindex in the contract",
           [500, :verbose, max_size: 1000, constraint_tries: 100_000],
           %{contract: contract} do
    forall leaves <- such_that(leaves <- list(binary()), when: length(leaves) > 0) do
      leaves_length = length(leaves)
      root_hash = Merkle.hash(leaves)

      forall txindex <- integer(0, leaves_length - 1) do
        proof = Merkle.create_tx_proof(leaves, txindex)
        leaf = Enum.at(leaves, txindex)

        forall other_txindex <- such_that(other_txindex <- non_neg_integer(), when: other_txindex != txindex) do
          not solidity_proof_valid(leaf, other_txindex, root_hash, proof, contract)
        end
      end
    end
  end

  # FIXME:
  # - how to smartly try to trick the validator?
  #    - mutate the leaf using the merkle tree (can expand the above property, otherwise it's trivial)
  #    - mutate the proof also. Mutate within the domain of the tripplet: leaf, index, proof. Keep the root hash and tree

  # FIXME: full 2**16 merkle trees, >2**16 proofs and trees (?) - property test or not?

  # FIXME: copy pasted from conformance/case.ex do sth about this
  # taken from the plasma-contracts deployment snapshot
  # this parsing occurs in several places around the codebase
  defp parse_contracts() do
    local_umbrella_path = Path.join([File.cwd!(), "../../", "localchain_contract_addresses.env"])

    contract_addreses_path =
      case File.exists?(local_umbrella_path) do
        true ->
          local_umbrella_path

        _ ->
          # CI/CD
          Path.join([File.cwd!(), "localchain_contract_addresses.env"])
      end

    contract_addreses_path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> List.flatten()
    |> Enum.reduce(%{}, fn line, acc ->
      [key, value] = String.split(line, "=")
      Map.put(acc, key, value)
    end)
  end
end
