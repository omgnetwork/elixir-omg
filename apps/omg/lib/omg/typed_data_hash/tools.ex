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

defmodule OMG.TypedDataHash.Tools do
  @moduledoc """
  Implements EIP-712 structural hashing primitives for Transaction type.
  See also: http://eips.ethereum.org/EIPS/eip-712
  """

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  # FIXME: chainId added here, see below
  @domain_encoded_type "EIP712Domain(string name,string version,address verifyingContract,bytes32 salt,uint256 chainId)"
  @domain_type_hash Crypto.hash(@domain_encoded_type)

  @transaction_encoded_type "Transaction(" <>
                              "Input input0,Input input1,Input input2,Input input3," <>
                              "Output output0,Output output1,Output output2,Output output3," <>
                              "bytes32 metadata)"
  @input_encoded_type "Input(uint256 blknum,uint256 txindex,uint256 oindex)"
  @output_encoded_type "Output(address owner,address currency,uint256 amount)"

  @transaction_type_hash Crypto.hash(@transaction_encoded_type <> @input_encoded_type <> @output_encoded_type)
  @input_type_hash Crypto.hash(@input_encoded_type)
  @output_type_hash Crypto.hash(@output_encoded_type)

  @doc """
  Computes Domain Separator `hashStruct(eip712Domain)`,
  @see: http://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator
  """
  @spec domain_separator(binary(), binary(), Crypto.address_t(), Crypto.hash_t()) ::
          Crypto.hash_t()
  def domain_separator(name, version, verifying_contract, salt) do
    [
      @domain_type_hash,
      Crypto.hash(name),
      Crypto.hash(version),
      ABI.TypeEncoder.encode_raw([verifying_contract], [:address]),
      ABI.TypeEncoder.encode_raw([salt], [{:bytes, 32}]),
      # FIXME: chainID added, while we don't want it here. Without chainId, parity wouldn't sign for us
      #        c.f. https://github.com/paritytech/parity-ethereum/issues/10832
      ABI.TypeEncoder.encode_raw([1], [{:uint, 256}])
    ]
    |> Enum.join()
    |> Crypto.hash()
  end

  @spec hash_transaction(
          list(Utxo.Position.t()),
          list(Transaction.output()),
          Transaction.metadata(),
          Crypto.hash_t(),
          Crypto.hash_t()
        ) :: Crypto.hash_t()
  def hash_transaction(inputs, outputs, metadata, empty_input_hash, empty_output_hash) do
    require Transaction

    input_hashes =
      inputs
      |> Stream.map(&hash_input/1)
      |> Stream.concat(Stream.cycle([empty_input_hash]))
      |> Enum.take(Transaction.max_inputs())

    output_hashes =
      outputs
      |> Stream.map(&hash_output/1)
      |> Stream.concat(Stream.cycle([empty_output_hash]))
      |> Enum.take(Transaction.max_outputs())

    [
      @transaction_type_hash,
      input_hashes,
      output_hashes,
      metadata || <<0::256>>
    ]
    |> List.flatten()
    |> Enum.join()
    |> Crypto.hash()
  end

  @spec hash_input(Utxo.Position.t()) :: Crypto.hash_t()
  def hash_input(Utxo.position(blknum, txindex, oindex)) do
    [
      @input_type_hash,
      ABI.TypeEncoder.encode_raw([blknum], [{:uint, 256}]),
      ABI.TypeEncoder.encode_raw([txindex], [{:uint, 256}]),
      ABI.TypeEncoder.encode_raw([oindex], [{:uint, 256}])
    ]
    |> Enum.join()
    |> Crypto.hash()
  end

  @spec hash_output(Transaction.output()) :: Crypto.hash_t()
  def hash_output(%{owner: owner, currency: currency, amount: amount}) do
    [
      @output_type_hash,
      ABI.TypeEncoder.encode_raw([owner], [:address]),
      ABI.TypeEncoder.encode_raw([currency], [:address]),
      ABI.TypeEncoder.encode_raw([amount], [{:uint, 256}])
    ]
    |> Enum.join()
    |> Crypto.hash()
  end
end
