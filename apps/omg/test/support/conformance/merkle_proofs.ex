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

    try do
      {:ok, result} = Eth.call_contract(contract, signature, args, return_types)
      result
      # FIXME: some incorrect proofs throw, and end up returning something that the ABI decoder borks on (looks like
      #        reason). Rethink here
    rescue
      e in CaseClauseError ->
        # this is the reason, attempted to be decoded as a bool or something. See fixme above. Asserting just in case
        %{term: 3_963_877_391_197_344_453_575_983_046_348_115_674_221_700_746_820_753_546_331_534_351_508_065_746_944} =
          e

        false
    end
  end
end
