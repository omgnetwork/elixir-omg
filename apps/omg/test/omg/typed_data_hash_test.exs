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

  @test_domain_separator Tools.domain_separator(
                           "OMG Network",
                           "1",
                           "44de0ec539b8c4a4b530c78620fe8320167f2f74" |> Base.decode16!(case: :mixed),
                           "fad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83"
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

      assert "96c33f4f5d36248f3885b7eef86aef0b5b22c78609d6a1e4e716db1854b3586f" ==
               Tools.hash_output(to_output.(output1)) |> Base.encode16(case: :lower)

      assert "0a7e96daa5e6e390e3302ad0f3215abfc430b1f4fbd1b60793462e9db72dd2df" ==
               Tools.hash_output(to_output.(output2)) |> Base.encode16(case: :lower)

      assert "594795caf8154c6c4023c627b44831d7b7a55ffaa9a2acc7e938993d18ea32ae" ==
               Tools.hash_output(to_output.(output3)) |> Base.encode16(case: :lower)

      assert "1171715d9d7d4d25b206621d80fd66c71beb59c1933fc3f2266ebc5607202fb8" ==
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
      assert "86b1c850f5221d40683097c9257dd13ee50964089ed3080ebd7ddc0a733adff3" ==
               TypedDataHash.hash_transaction(Transaction.new([], [])) |> Base.encode16(case: :lower)

      assert "444ec233a0a80d7a40aff0bc53462543994aa088b2d0a3e635acc57176076ef8" ==
               TypedDataHash.hash_transaction(Transaction.new(inputs, outputs))
               |> Base.encode16(case: :lower)

      assert "636491ffc56c65f51760e1149da96e1f1605815ba21efe4ffa4c9a18ce7a0560" ==
               TypedDataHash.hash_transaction(Transaction.new(inputs, outputs, metadata))
               |> Base.encode16(case: :lower)
    end

    test "Structured hash is computed correctly", %{inputs: inputs, outputs: outputs, metadata: metadata} do
      assert "992ac0f45bff7d9fb74636623e5d8b111b49b818cadcf3a91c035735a84d154f" ==
               TypedDataHash.hash_struct(Transaction.new([], []), @test_domain_separator) |> Base.encode16(case: :lower)

      assert "b42dc40570279af9faa05e64d62f54db0fd2b768a4a69646efba068cf88eb7a2" ==
               TypedDataHash.hash_struct(Transaction.new(inputs, outputs), @test_domain_separator)
               |> Base.encode16(case: :lower)

      assert "5f9adeaaba8d2fa17de40f45eb12136c7e7f26ea56567226274314d0a563e81d" ==
               TypedDataHash.hash_struct(Transaction.new(inputs, outputs, metadata), @test_domain_separator)
               |> Base.encode16(case: :lower)
    end
  end

  describe "Signature compliance with Metamask" do
    # This account was used with metamask to create signatures - do not change!
    @signer <<34, 88, 165, 39, 152, 80, 246, 251, 120, 136, 138, 126, 69, 234, 42, 94, 177, 179, 196, 54>>

    test "test #0" do
      signature =
        "55d95900e5bffef27e6225c6ff4cbe1d18cbc28281583a24402ceec80aa924db337f9f663a6a80ca153497cd328e2a0b49d896b66d640e785f59eb76a37cb9aa1b"
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
        "836c4c3726674a93e9d034a60152a64c7de0b55670bbed0c228647ca3797d5b043fea4325452eec47e644dd9124e46d7334b22997dbbbb3cf7b81f2a02a81ccd1c"
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
        "7b0c9abe27135205c82571b9e4fcbf0641ba9db05d4d8256db3b8f0680a3a55729058aabb15b0f9a101325d60ec1730ae6dd907efd86dcb98cad88616d64a92d1c"
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
