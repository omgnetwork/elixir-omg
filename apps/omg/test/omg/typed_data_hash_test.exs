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
                           verifyingContract: Base.decode16!("44de0ec539b8c4a4b530c78620fe8320167f2f74", case: :mixed),
                           salt:
                             Base.decode16!("fad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
                               case: :mixed
                             )
                         })

  setup_all do
    null_addr = <<0::160>>
    owner = Base.decode16!("2258a5279850f6fb78888a7e45ea2a5eb1b3c436", case: :mixed)
    token = Base.decode16!("0123456789abcdef000000000000000000000000", case: :mixed)

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
       metadata: Base.decode16!("853a8d8af99c93405a791b97d57e819e538b06ffaa32ad70da2582500bc18d43", case: :mixed)
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
      expected = "9fd642c2bbaa2f3431add55df5d3932807048fb41b6b07d65c59e0f9ad3a8eb7"

      assert expected ==
               "Output(uint256 outputType,bytes20 outputGuard,address currency,uint256 amount)"
               |> Crypto.hash()
               |> Base.encode16(case: :lower)
    end

    test "Transaction type hash is computed correctly" do
      expected = "186aebaa7ec9e4abef44830c07670c034d8efb44e91542dc63df2f65205e61cc"

      full_type =
        "Transaction(" <>
          "Input input0,Input input1,Input input2,Input input3," <>
          "Output output0,Output output1,Output output2,Output output3," <>
          "uint256 txdata,bytes32 metadata)" <>
          "Input(uint256 blknum,uint256 txindex,uint256 oindex)" <>
          "Output(uint256 outputType,bytes20 outputGuard,address currency,uint256 amount)"

      assert expected == full_type |> Crypto.hash() |> Base.encode16(case: :lower)
    end

    test "domain separator is computed correctly" do
      expected = "b542beb7bafc6796b8439716a4e460a2634ac432216cebc524e54f8789e2924c"

      assert expected == Base.encode16(@test_domain_separator, case: :lower)
    end

    test "Input is hashed properly" do
      assert "1a5933eb0b3223b0500fbbe7039cab9badc006adda6cf3d337751412fd7a4b61" ==
               Utxo.position(0, 0, 0) |> Tools.hash_input() |> Base.encode16(case: :lower)

      assert "7377afcd24fdc685fd8c6ea2b5d15a74f2c898c3d5bcce3499f448a4d68db290" ==
               Utxo.position(1, 0, 0) |> Tools.hash_input() |> Base.encode16(case: :lower)

      assert "c198a0ab9b12c3f225195cf0f7870c7ab12c316b33eb99771dfd0f3f7da455a5" ==
               Utxo.position(101_000, 1337, 3) |> Tools.hash_input() |> Base.encode16(case: :lower)
    end

    test "Output is hashed properly", %{outputs: [output1, output2, output3, output4]} do
      to_output = fn {owner, currency, amount} ->
        [output] = Transaction.get_outputs(Transaction.Payment.new([], [{owner, currency, amount}]))

        output
      end

      assert "4b85fe2caac41f533c3d3b56ec75ca3363d0205e4dde63ca16b0d377fa79364d" ==
               to_output.(output1) |> Tools.hash_output() |> Base.encode16(case: :lower)

      assert "27962e5f1453285204261a3b2fe420be5ee504f3606d857e5c3120e1fc7aac3f" ==
               to_output.(output2) |> Tools.hash_output() |> Base.encode16(case: :lower)

      assert "257ce332ccd9571fb364f8abd0b22ca53cd3d7e4ba9a14fd208cdf25caf8854f" ==
               to_output.(output3) |> Tools.hash_output() |> Base.encode16(case: :lower)

      assert "168031cd8ed05efce595276a59045cabf7a33d14a4dcad1ea16fdd0c98ad7598" ==
               to_output.(output4) |> Tools.hash_output() |> Base.encode16(case: :lower)
    end

    test "Metadata is hashed properly", %{metadata: metadata} do
      empty = <<0::256>>

      assert "290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563" ==
               empty |> Crypto.hash() |> Base.encode16(case: :lower)

      assert "f32aecc93539658c0e9f102ad05b1f37ec4692366142955451b7e432f59a513a" ==
               metadata |> Crypto.hash() |> Base.encode16(case: :lower)
    end

    test "Transaction is hashed correctly", %{inputs: inputs, outputs: outputs, metadata: metadata} do
      assert "3f5b24d7cf1db32c34ae2921a3537b7af40ad7e787fb7e8e03f88715a861dfe7" ==
               Transaction.Payment.new([], []) |> TypedDataHash.hash_transaction() |> Base.encode16(case: :lower)

      assert "d5fb24437003566da84b8948fde09c367bbf93da39cdd23390ecaa98e3054f2d" ==
               Transaction.Payment.new(inputs, outputs)
               |> TypedDataHash.hash_transaction()
               |> Base.encode16(case: :lower)

      assert "7c3f89120b00c4b1ca433811b544e8177f109c5a4ca27ff434e08b02d66e77f4" ==
               Transaction.Payment.new(inputs, outputs, metadata)
               |> TypedDataHash.hash_transaction()
               |> Base.encode16(case: :lower)
    end

    test "Structured hash is computed correctly", %{inputs: inputs, outputs: outputs, metadata: metadata} do
      assert "47f83702c496c7ebb6ec639cb11d6c8b81eb64f6d818cb087e3ed2cb92ccf1ae" ==
               Transaction.Payment.new([], [])
               |> TypedDataHash.hash_struct(@test_domain_separator)
               |> Base.encode16(case: :lower)

      assert "aeaa272f4460436415f377cb0cefe8f2646f4457f60827519a7edf86d30c0bf0" ==
               Transaction.Payment.new(inputs, outputs)
               |> TypedDataHash.hash_struct(@test_domain_separator)
               |> Base.encode16(case: :lower)

      assert "e1fcd0b07d8034ac039c15c544436a95e92879689a456604cbc0e8420e6e342a" ==
               Transaction.Payment.new(inputs, outputs, metadata)
               |> TypedDataHash.hash_struct(@test_domain_separator)
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
               "uint256 txData,bytes32 metadata)" ==
               TypedDataHash.Types.encode_type(:Transaction)

      assert "Input(uint256 blknum,uint256 txindex,uint256 oindex)" ==
               TypedDataHash.Types.encode_type(:Input)

      assert "Output(uint256 outputType,bytes20 outputGuard,address currency,uint256 amount)" ==
               TypedDataHash.Types.encode_type(:Output)
    end
  end
end
