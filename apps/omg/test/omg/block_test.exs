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

defmodule OMG.BlockTest do
  @moduledoc """
  Simple unit test of part of `OMG.Block`.
  """

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Block
  alias OMG.TestHelper

  defp eth, do: OMG.Eth.RootChain.eth_pseudo_address()

  describe "hashed_txs_at/2" do
    @tag fixtures: [:stable_alice, :stable_bob]
    test "returns a block with the list of transactions and a computed merkle root hash", %{
      stable_alice: alice,
      stable_bob: bob
    } do
      tx_1 = TestHelper.create_recovered([{1, 0, 0, alice}], eth(), [{bob, 100}])
      tx_2 = TestHelper.create_recovered([{1, 1, 1, alice}], eth(), [{bob, 100}])

      transactions = [tx_1, tx_2]

      assert Block.hashed_txs_at(transactions, 10) == %Block{
               hash:
                 <<34, 146, 42, 183, 241, 237, 118, 74, 89, 216, 33, 45, 171, 175, 216, 24, 97, 154, 90, 81, 21, 199,
                   155, 254, 64, 112, 96, 58, 205, 178, 162, 77>>,
               number: 10,
               transactions: [
                 tx_1.signed_tx_bytes,
                 tx_2.signed_tx_bytes
               ]
             }
    end

    test "handles an empty list of transactions" do
      assert Block.hashed_txs_at([], 10) == %Block{
               hash:
                 <<119, 106, 49, 219, 52, 161, 160, 167, 202, 175, 134, 44, 255, 223, 255, 23, 137, 41, 127, 250, 220,
                   56, 11, 211, 211, 146, 129, 211, 64, 171, 211, 173>>,
               number: 10,
               transactions: []
             }
    end
  end

  describe "to_api_format/1" do
    test "formats to map for API" do
      block = %Block{
        hash: "hash",
        number: 10,
        transactions: ["tx_1_bytes", "tx_2_bytes"]
      }

      assert Block.to_api_format(block) == %{
               blknum: 10,
               hash: "hash",
               transactions: ["tx_1_bytes", "tx_2_bytes"]
             }
    end
  end

  describe "to_db_value/1" do
    test "formats to DB format with valid inputs" do
      block = %Block{
        hash: "hash",
        number: 10,
        transactions: ["tx_1_bytes", "tx_2_bytes"]
      }

      assert Block.to_db_value(block) == %{
               hash: "hash",
               number: 10,
               transactions: ["tx_1_bytes", "tx_2_bytes"]
             }
    end

    test "fails to format when the list of transactions is not a list" do
      # Not sure how we want to handle this, there is currently no
      # fallback function in the Block module
      assert_raise FunctionClauseError, fn ->
        Block.to_db_value(%Block{
          hash: "hash",
          number: 10,
          transactions: %{}
        })
      end
    end

    test "fails to format when the hash is not a binary" do
      assert_raise FunctionClauseError, fn ->
        Block.to_db_value(%Block{
          hash: 1,
          number: 10,
          transactions: []
        })
      end
    end

    test "fails to format when the number is not an integer" do
      assert_raise FunctionClauseError, fn ->
        Block.to_db_value(%Block{
          hash: 1,
          number: "10",
          transactions: []
        })
      end
    end
  end

  describe "from_db_value/1" do
    test "formats from DB format with valid inputs" do
      block = %{
        hash: "hash",
        number: 10,
        transactions: ["tx_1_bytes", "tx_2_bytes"]
      }

      assert Block.from_db_value(block) == %Block{
               hash: "hash",
               number: 10,
               transactions: ["tx_1_bytes", "tx_2_bytes"]
             }
    end

    test "fails to format when the list of transactions is not a list" do
      # Not sure how we want to handle this, there is currently no
      # fallback function in the Block module
      assert_raise FunctionClauseError, fn ->
        Block.from_db_value(%{
          hash: "hash",
          number: 10,
          transactions: %{}
        })
      end
    end

    test "fails to format when the hash is not a binary" do
      assert_raise FunctionClauseError, fn ->
        Block.from_db_value(%{
          hash: 1,
          number: 10,
          transactions: []
        })
      end
    end

    test "fails to format when the number is not an integer" do
      assert_raise FunctionClauseError, fn ->
        Block.from_db_value(%{
          hash: 1,
          number: "10",
          transactions: []
        })
      end
    end
  end

  describe "inclusion_proof/2" do
    @tag fixtures: [:stable_alice]
    test "calculates the inclusion proof when a list of transactions is given", %{
      stable_alice: alice
    } do
      tx_1 = TestHelper.create_encoded([{1, 0, 0, alice}], eth(), [{alice, 7}])
      tx_2 = TestHelper.create_encoded([{1, 1, 0, alice}], eth(), [{alice, 2}])

      encoded_proof =
        [tx_1, tx_2]
        |> Block.inclusion_proof(1)
        |> Base.encode16(case: :lower)

      assert "491b9e07c4997c976c38a91f" <> _ = encoded_proof
    end

    @tag fixtures: [:stable_alice]
    test "calculates the inclusion proof when a block is given", %{
      stable_alice: alice
    } do
      tx_1 = TestHelper.create_encoded([{1, 0, 0, alice}], eth(), [{alice, 7}])
      tx_2 = TestHelper.create_encoded([{1, 1, 0, alice}], eth(), [{alice, 2}])

      encoded_proof =
        %Block{transactions: [tx_1, tx_2]}
        |> Block.inclusion_proof(1)
        |> Base.encode16(case: :lower)

      assert "491b9e07c4997c976c38a91f" <> _ = encoded_proof
    end

    test "calculates the inclusion proof when an empty list is given" do
      encoded_proof =
        []
        |> Block.inclusion_proof(1)
        |> Base.encode16(case: :lower)

      assert "290decd9548b62a8d60345a9" <> _ = encoded_proof
    end

    test "raises an error when an invalid input is given (map)" do
      assert_raise FunctionClauseError, fn ->
        Block.inclusion_proof(%{}, 1)
      end
    end

    @tag fixtures: [:stable_alice, :stable_bob]
    test "Block merkle proof smoke test", %{
      stable_alice: alice
    } do
      # this checks merkle proof normally tested via speaking to the contract (integration tests) against
      # a fixed binary. The motivation for having such test is a quick test of whether the merkle proving didn't change

      # odd number of transactions, just in case
      tx_1 = TestHelper.create_encoded([{1, 0, 0, alice}], eth(), [{alice, 7}])
      tx_2 = TestHelper.create_encoded([{1, 1, 0, alice}], eth(), [{alice, 2}])
      tx_3 = TestHelper.create_encoded([{1, 0, 1, alice}], eth(), [{alice, 2}])

      txs = [tx_1, tx_2, tx_3]
      assert Block.inclusion_proof(txs, 1) == Block.inclusion_proof(%Block{transactions: txs}, 1)

      assert %Block{transactions: [tx_1, tx_2, tx_3]}
             |> Block.inclusion_proof(2)
             |> Base.encode16(case: :lower) ==
               "290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563c62f5e8b8c8303e7845c0e8ea800fc1bae9ccb7782b6f3c870c2d48fdddf5bb4890740a8eb06ce9be422cb8da5cdafc2b58c0a5e24036c578de2a433c828ff7d3b8ec09e026fdc305365dfc94e189a81b38c7597b3d941c279f042e8206e0bd8ecd50eee38e386bd62be9bedb990706951b65fe053bd9d8a521af753d139e2dadefff6d330bb5403f63b14f33b578274160de3a50df4efecf0e0db73bcdd3da5617bdd11f7c0a11f49db22f629387a12da7596f9d1704d7465177c63d88ec7d7292c23a9aa1d8bea7e2435e555a4a60e379a5a35f3f452bae60121073fb6eeade1cea92ed99acdcb045a6726b2f87107e8a61620a232cf4d7d5b5766b3952e107ad66c0a68c72cb89e4fb4303841966e4062a76ab97451e3b9fb526a5ceb7f82e026cc5a4aed3c22a58cbd3d2ac754c9352c5436f638042dca99034e836365163d04cffd8b46a874edf5cfae63077de85f849a660426697b06a829c70dd1409cad676aa337a485e4728a0b240d92b3ef7b3c372d06d189322bfd5f61f1e7203ea2fca4a49658f9fab7aa63289c91b7c7b6c832a6d0e69334ff5b0a3483d09dab4ebfd9cd7bca2505f7bef59cc1c12ecc708fff26ae4af19abe852afe9e20c8622def10d13dd169f550f578bda343d9717a138562e0093b380a1120789d53cf10"
    end

    @tag fixtures: [:alice]
    test "Block merkle proof smoke test for deposit transactions",
         %{alice: alice} do
      tx = TestHelper.create_encoded([], eth(), [{alice, 7}])
      proof = Block.inclusion_proof(%Block{transactions: [tx]}, 0)

      assert is_binary(proof)
      assert byte_size(proof) == 32 * 16
    end
  end
end
