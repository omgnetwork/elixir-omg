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

defmodule Support.Conformance.MerkleProofs do
  @moduledoc """
  Utility functions that used when testing Elixir vs Solidity implementation conformance
  """
  alias OMG.Eth
  # FIXME imports
  # alias OMG.State.Transaction

  # import ExUnit.Assertions, only: [assert: 1, assert: 2]

  def solidity_proof_valid(leaf, index, root_hash, proof, contract) do
    signature = "checkMembership(bytes,uint256,bytes32,bytes)"
    args = [leaf, index, root_hash, proof]
    return_types = [:bool]
    {:ok, result} = Eth.call_contract(contract, signature, args, return_types)
    result
  end
end
