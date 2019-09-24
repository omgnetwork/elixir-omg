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

defmodule OMG.TypedDataHashTest do
  @moduledoc """
  Idea behind testing functionality like this (which produces random byte-strings) is 4-tiered test suite.
  * tier 1: acknowledged third party (Metamask) signatures we can verify (recover address from)
  * tier 2: final structural hash on prepared transaction that gives the same signatures as above
  * tier 3: intermediate results of hashing (domain separator, structural hashes of inputs & outputs)
  * tier 4: end-to-end test of generating signatures in elixir code and verifying them in solidity library (
    done in `OMG.DependencyConformance.SignatureTest`)
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

  @test_domain_separator Tools.domain_separator(%{
                           name: "OMG Network",
                           version: "1",
                           verifyingContract:
                             "44de0ec539b8c4a4b530c78620fe8320167f2f74" |> Base.decode16!(case: :mixed),
                           salt:
                             "fad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83"
                             |> Base.decode16!(case: :mixed)
                         })

  setup_all do
    null_addr = <<0::160>>
    owner = "2258a5279850f6fb78888a7e45ea2a5eb1b3c436" |> Base.decode16!(case: :mixed)
    token = "0123456789abcdef000000000000000000000000" |> Base.decode16!(case: :mixed)

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
       metadata: "853a8d8af99c93405a791b97d57e819e538b06ffaa32ad70da2582500bc18d43" |> Base.decode16!(case: :mixed)
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
      expected = "b542beb7bafc6796b8439716a4e460a2634ac432216cebc524e54f8789e2924c"

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

      assert "ab6467081c7b782378b188e4e7e6e769b8ca4e24f6506caa529ce23423ecd0a4" ==
               Tools.hash_output(to_output.(output1)) |> Base.encode16(case: :lower)

      assert "cd29671159482b06d18128343d9be9825e68df94ac7384e3b58e0474f31d017f" ==
               Tools.hash_output(to_output.(output2)) |> Base.encode16(case: :lower)

      assert "e143688bfd8c20c163fda04b736c0ddbc085d9cd113630545e0da908acf9dcf0" ==
               Tools.hash_output(to_output.(output3)) |> Base.encode16(case: :lower)

      assert "a3f97133bb62989c1c848c8bdcefbe68d03f9bf97c9b066cf6923b3e3a06ea68" ==
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
      assert "b2b6ae7a5a92e58adf1d554d675906ff557df278ae1297f8fa9b01f01dede6b6" ==
               TypedDataHash.hash_transaction(Transaction.Payment.new([], [])) |> Base.encode16(case: :lower)

      assert "88541c996667133fb693974c032b9ca94582e2f5629dfd3c8f681220ea57c4a6" ==
               TypedDataHash.hash_transaction(Transaction.Payment.new(inputs, outputs))
               |> Base.encode16(case: :lower)

      assert "312a9d61c2ead1ec95c0213caefaf5a6dcaf1f1f8cd3f807e4d7336fc977b7c1" ==
               TypedDataHash.hash_transaction(Transaction.Payment.new(inputs, outputs, metadata))
               |> Base.encode16(case: :lower)
    end

    test "Structured hash is computed correctly", %{inputs: inputs, outputs: outputs, metadata: metadata} do
      assert "554368e062dba0a496463941733fbe37cdb8e9169ba0744d7b23154372528364" ==
               TypedDataHash.hash_struct(Transaction.Payment.new([], []), @test_domain_separator)
               |> Base.encode16(case: :lower)

      assert "1f6cc38540d402435ff4e8300adc91044f32ff229f343d5ec74b3de749d119d7" ==
               TypedDataHash.hash_struct(Transaction.Payment.new(inputs, outputs), @test_domain_separator)
               |> Base.encode16(case: :lower)

      assert "a3911ce926e4b42722a39e6347e9d7d96c6df03bea6894a00cc3eab40c31c79a" ==
               TypedDataHash.hash_struct(Transaction.Payment.new(inputs, outputs, metadata), @test_domain_separator)
               |> Base.encode16(case: :lower)
    end
  end

  describe "Eip-712 types" do
    test "align with encodeType format" do
      assert "EIP712Domain(string name,string version,address verifyingContract,bytes32 salt)" ==
               TypedDataHash.Types.encode_type(:EIP712Domain)

      assert "Transaction(" <>
               "uint256 txType," <>
               "Input input0,Input input1,Input input2,Input input3," <>
               "Output output0,Output output1,Output output2,Output output3," <>
               "bytes32 metadata)" ==
               TypedDataHash.Types.encode_type(:Transaction)

      assert "Input(uint256 blknum,uint256 txindex,uint256 oindex)" ==
               TypedDataHash.Types.encode_type(:Input)

      assert "Output(bytes20 owner,address currency,uint256 amount)" ==
               TypedDataHash.Types.encode_type(:Output)
    end
  end
end
