# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.TypedDataHashTest do
  @moduledoc """
  Idea behind testing functionality like this (which produces random byte-strings) is 4-tiered test suite.
  * tier 1: acknowledged third party (Metamask) signatures we can verify (recover address from)
  * tier 2: final structural hash on prepared transaction that gives the same signatures as above
  * tier 3: intermediate results of hashing (domain separator, structural hashes of inputs & outputs)
  * tier 4: end-to-end test of generating signatures in elixir code and verifying them in solidity library (
    done in https://github.com/omisego/elixir-omg/pull/656)
  """

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.TypedDataHash
  alias OMG.TypedDataHash.Tools
  alias OMG.Utxo

  require Utxo
  require OMG.TypedDataHash.Tools

  @chain_id 4
  @test_domain_separator Tools.domain_separator(
                           "OMG Network",
                           "1",
                           @chain_id,
                           "1C56346CD2A2Bf3202F771f50d3D14a367B48070" |> Base.decode16!(case: :mixed),
                           "f2d857f4a3edcb9b78b4d503bfe733db1e3f6cdc2b7971ee739626c97e86a558"
                           |> Base.decode16!(case: :mixed)
                         )

  setup_all do
    null_addr = <<0::160>>
    owner = "2258a5279850f6fb78888a7e45ea2a5eb1b3c436" |> Base.decode16!(case: :lower)
    token = "0123456789abcdef000000000000000000000000" |> Base.decode16!(case: :lower)

    {:ok,
     %{
       inputs: [
         {1, 0, 0},
         {1000, 2, 3},
         {101_000, 1337, 3}
       ],
       outputs: [
         {owner, null_addr, 100},
         {token, null_addr, 111},
         {owner, token, 1337},
         {null_addr, null_addr, 0}
       ],
       metadata: "853a8d8af99c93405a791b97d57e819e538b06ffaa32ad70da2582500bc18d43" |> Base.decode16!(case: :lower)
     }}
  end

  describe "Compliance with contract code" do
    test "EIP domain type is encoded correctly" do
      eip_domain = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
      expected_hash = "d87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472"

      assert expected_hash == eip_domain |> Crypto.hash() |> Base.encode16(case: :lower)
    end

    test "Input type hash is computed correctly" do
      expected = "5f0e06e50b513a68a090818949172483acfec769d9b7756cad7c00b26b52178c"

      assert expected ==
               "Input(uint256 blknum,uint256 txindex,uint256 oindex)" |> Crypto.hash() |> Base.encode16(case: :lower)
    end

    test "Output type hash is computed correctly" do
      expected = "44a2b66b59d762782e867c9a6d8ab5a03eed0dcef5f1dd3092455b4701a5c65b"

      assert expected ==
               "Output(address owner,address token,uint256 amount)" |> Crypto.hash() |> Base.encode16(case: :lower)
    end

    test "Transaction type hash is computed correctly" do
      expected = "73f5401d37a3fdbb9bc225b971d5b78cf16f2e53076434f577773b0d9edf3e7a"

      full_type =
        "Transaction(" <>
          "Input input0,Input input1,Input input2,Input input3," <>
          "Output output0,Output output1,Output output2,Output output3," <>
          "bytes32 metadata)" <>
          "Input(uint256 blknum,uint256 txindex,uint256 oindex)" <>
          "Output(address owner,address token,uint256 amount)"

      assert expected == full_type |> Crypto.hash() |> Base.encode16(case: :lower)
    end

    test "domain separator is computed correctly" do
      expected = "d42a6f7e5730ebf9ab9a2802b60543ccf4a220a0f3a3e6b97f5226cfcf30b0f5"

      assert expected ==
               @test_domain_separator
               |> Base.encode16(case: :lower)
    end

    test "Input is hashed properly" do
      assert "1a5933eb0b3223b0500fbbe7039cab9badc006adda6cf3d337751412fd7a4b61" ==
               Tools.hash_input(Utxo.position(0, 0, 0)) |> Base.encode16(case: :lower)

      assert "7377afcd24fdc685fd8c6ea2b5d15a74f2c898c3d5bcce3499f448a4d68db290" ==
               Tools.hash_input(Utxo.position(1, 0, 0)) |> Base.encode16(case: :lower)

      assert "c198a0ab9b12c3f225195cf0f7870c7ab12c316b33eb99771dfd0f3f7da455a5" ==
               Tools.hash_input(Utxo.position(101_000, 1337, 3)) |> Base.encode16(case: :lower)
    end

    test "Output is hashed properly", %{outputs: [output1, output2, output3, output4]} do
      to_output = fn {owner, currency, amount} -> %{owner: owner, currency: currency, amount: amount} end

      assert "2d7e855c4ed0b5442749af2f2e1654a1d005d7f33c74db997112aa746362331a" ==
               Tools.hash_output(to_output.(output1)) |> Base.encode16(case: :lower)

      assert "6ea3ef954bc4b17441b63a96a0014f033583456ac0187a8497959a390c83bb82" ==
               Tools.hash_output(to_output.(output2)) |> Base.encode16(case: :lower)

      assert "3084addf822b16a011704753552a98545d33df967386e14f00ba3ab4faaaa80b" ==
               Tools.hash_output(to_output.(output3)) |> Base.encode16(case: :lower)

      assert "853a8d8af99c93405a791b97d57e819e538b06ffaa32ad70da2582500bc18d43" ==
               Tools.hash_output(to_output.(output4)) |> Base.encode16(case: :lower)
    end

    test "Metadata is hashed properly", %{metadata: metadata} do
      empty = <<0::256>>

      assert "290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563" ==
               Crypto.hash(empty) |> Base.encode16(case: :lower)

      assert "f32aecc93539658c0e9f102ad05b1f37ec4692366142955451b7e432f59a513a" ==
               Crypto.hash(metadata) |> Base.encode16(case: :lower)
    end

    test "Transaction is hashed correctly", %{inputs: inputs, outputs: outputs, metadata: metadata} do
      assert "cd7d70602e84b8a52123727394b8fdba87380cc03a91c8ab1c0baa7dde7c3558" ==
               TypedDataHash.hash_transaction(Transaction.new([], [])) |> Base.encode16(case: :lower)

      assert "25ad23b53146d4462a31bfe7c44a67d8fa0fc3c9bb9366a39c1a26b4f20e3231" ==
               TypedDataHash.hash_transaction(Transaction.new(inputs, outputs))
               |> Base.encode16(case: :lower)

      assert "e2af729df6f59730dd7f39c9f60b6eb293b1ad128e059fe70fc146ce77d3c9b9" ==
               TypedDataHash.hash_transaction(Transaction.new(inputs, outputs, metadata))
               |> Base.encode16(case: :lower)
    end

    test "Structured hash is computed correctly", %{inputs: inputs, outputs: outputs, metadata: metadata} do
      assert "0aa26a80d09f12d1f03b8bd0dcfd66fb5776554b326a56d21cfdfdc25254a9c4" ==
               TypedDataHash.hash_struct(Transaction.new([], []), @test_domain_separator) |> Base.encode16(case: :lower)

      assert "71e72678fe793358b35855734a9987d4d377bb1f9b5d4b04b8f2554a34e51628" ==
               TypedDataHash.hash_struct(Transaction.new(inputs, outputs), @test_domain_separator)
               |> Base.encode16(case: :lower)

      assert "78ddf5f81d7e9271bc125ae6590a8aa27a630135c4f0ba094cd7fd7943a8a2f4" ==
               TypedDataHash.hash_struct(Transaction.new(inputs, outputs, metadata), @test_domain_separator)
               |> Base.encode16(case: :lower)
    end
  end

  describe "Signature compliance with Metamask" do
    # This account was used with metamask to create signatures - do not change!
    @signer <<34, 88, 165, 39, 152, 80, 246, 251, 120, 136, 138, 126, 69, 234, 42, 94, 177, 179, 196, 54>>

    test "test #0" do
      signature =
        "00f291813e96fc5dcb236d6893de26d5a1dd1297615a20dce36b7515d37f94e51a0bf2bb122ff558f20e502eee14fc7d48fba89dcb9f4f0980185ff4ae65b15f1c"
        |> Base.decode16!(case: :lower)

      raw_tx = Transaction.new([], [])

      assert true ==
               raw_tx
               |> TypedDataHash.hash_struct(@test_domain_separator)
               |> Crypto.recover_address(signature)
               |> (&match?({:ok, @signer}, &1)).()
    end

    test "test #1", %{inputs: inputs, outputs: outputs} do
      signature =
        "467270afdecbe4fc9301d3dca63685dda7459530fae431e7b54e4b0899e5640577e703110423b20b9f2321b721e6eda4427820c1390fa778432ece5f206546da1c"
        |> Base.decode16!(case: :lower)

      raw_tx = Transaction.new(inputs, outputs)

      assert true ==
               raw_tx
               |> TypedDataHash.hash_struct(@test_domain_separator)
               |> Crypto.recover_address(signature)
               |> (&match?({:ok, @signer}, &1)).()
    end

    test "test #2", %{inputs: inputs, outputs: outputs, metadata: metadata} do
      signature =
        "f4a9fa3c09bbef23fc26f4a1a871b6f5f04a51b9d73a07096ffb8c08880d23112bcfc7748673121708d60a8efbeb15362582d8dd9c21d336c1be47763edd5ed11c"
        |> Base.decode16!(case: :lower)

      raw_tx = Transaction.new(inputs, outputs, metadata)

      assert true ==
               raw_tx
               |> TypedDataHash.hash_struct(@test_domain_separator)
               |> Crypto.recover_address(signature)
               |> (&match?({:ok, @signer}, &1)).()
    end
  end
end
