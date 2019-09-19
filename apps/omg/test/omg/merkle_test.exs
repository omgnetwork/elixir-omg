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

defmodule OMG.MerkleTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Merkle

  describe "create_tx_proof/2" do
    test "creates merkle proofs based on list of values and index" do
      # We don't want to be testing the underlying library here,
      # we just want to ensure that our code calling it always
      # return the same result
      values = ["abc", "def", "ghi"]

      proof_1 = Merkle.create_tx_proof(values, 1)
      proof_2 = Merkle.create_tx_proof(values, 2)

      assert proof_1 != proof_2
      assert "6162639621ddbb2d2631190" <> _ = Base.encode16(proof_1, case: :lower)
    end
  end

  describe "hash/1" do
    test "returns the merkle tree root for a list of transaction" do
      values = ["abc", "def", "ghi"]

      proof =
        values
        |> Merkle.hash()
        |> Base.encode16(case: :lower)

      assert proof == "5886d20993731f68ff6bc6b175f58aa2bddc09512eabe761aaf62ab57c086066"
    end
  end
end
