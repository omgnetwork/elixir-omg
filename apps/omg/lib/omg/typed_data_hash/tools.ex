# Copyright 2019-2020 OMG Network Pte Ltd
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
  alias OMG.Output
  alias OMG.State.Transaction
  alias OMG.TypedDataHash.Types
  alias OMG.Utxo

  require Utxo

  @type eip712_domain_t() :: %{
          name: binary(),
          version: binary(),
          salt: OMG.Crypto.hash_t(),
          verifyingContract: OMG.Crypto.address_t()
        }

  @domain_encoded_type Types.encode_type(:EIP712Domain)
  @domain_type_hash Crypto.hash(@domain_encoded_type)

  @transaction_encoded_type Types.encode_type(:Transaction)
  @input_encoded_type Types.encode_type(:Input)
  @output_encoded_type Types.encode_type(:Output)

  @transaction_type_hash Crypto.hash(@transaction_encoded_type <> @input_encoded_type <> @output_encoded_type)
  @input_type_hash Crypto.hash(@input_encoded_type)
  @output_type_hash Crypto.hash(@output_encoded_type)

  @doc """
  Computes Domain Separator `hashStruct(eip712Domain)`,
  @see: http://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator
  """
  @spec domain_separator(eip712_domain_t(), Crypto.hash_t()) :: Crypto.hash_t()
  def domain_separator(
        %{
          name: name,
          version: version,
          verifyingContract: verifying_contract,
          salt: salt
        },
        domain_type_hash \\ @domain_type_hash
      ) do
    [
      domain_type_hash,
      Crypto.hash(name),
      Crypto.hash(version),
      ABI.TypeEncoder.encode_raw([verifying_contract], [:address]),
      ABI.TypeEncoder.encode_raw([salt], [{:bytes, 32}])
    ]
    |> Enum.join()
    |> Crypto.hash()
  end

  @spec hash_transaction(
          non_neg_integer(),
          list(Utxo.Position.t()),
          list(Output.t()),
          Transaction.metadata(),
          Crypto.hash_t(),
          Crypto.hash_t()
        ) :: Crypto.hash_t()
  def hash_transaction(plasma_framework_tx_type, inputs, outputs, metadata, empty_input_hash, empty_output_hash) do
    require Transaction.Payment

    raw_encoded_tx_type = ABI.TypeEncoder.encode_raw([plasma_framework_tx_type], [{:uint, 256}])

    input_hashes =
      inputs
      |> Stream.map(&hash_input/1)
      |> Stream.concat(Stream.cycle([empty_input_hash]))
      |> Enum.take(Transaction.Payment.max_inputs())

    output_hashes =
      outputs
      |> Stream.map(&hash_output/1)
      |> Stream.concat(Stream.cycle([empty_output_hash]))
      |> Enum.take(Transaction.Payment.max_outputs())

    tx_data = ABI.TypeEncoder.encode_raw([0], [{:uint, 256}])
    metadata = metadata || <<0::256>>

    [
      @transaction_type_hash,
      raw_encoded_tx_type,
      input_hashes,
      output_hashes,
      tx_data,
      metadata
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

  @spec hash_output(Output.t()) :: Crypto.hash_t()
  def hash_output(%Output{
        owner: owner,
        currency: currency,
        amount: amount,
        output_type: output_type
      }) do
    [
      @output_type_hash,
      ABI.TypeEncoder.encode_raw([output_type], [{:uint, 256}]),
      ABI.TypeEncoder.encode_raw([owner], [{:bytes, 20}]),
      ABI.TypeEncoder.encode_raw([currency], [:address]),
      ABI.TypeEncoder.encode_raw([amount], [{:uint, 256}])
    ]
    |> Enum.join()
    |> Crypto.hash()
  end
end
