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

defmodule OMG.TypedDataSign do
  @moduledoc """
  Verifies typed structured data signatures (see: http://eips.ethereum.org/EIPS/eip-712)
  """

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Transaction
  require Utxo

  @domain_separator __MODULE__.Config.compute_domain_separator_from_config()
  @transaction_encoded_type "Transaction(" <>
                              "Input input0,Input input1,Input input2,Input input3," <>
                              "Output output0,Output output1,Output output2,Output output3," <>
                              "bytes32 metadata)"
  @input_encoded_type "Input(uint256 blknum,uint256 txindex,uint256 oindex)"
  @output_encoded_type "Output(address owner,address token,uint256 amount)"

  @transaction_type_hash Crypto.hash(@transaction_encoded_type <> @input_encoded_type <> @output_encoded_type)
  @input_type_hash Crypto.hash(@input_encoded_type)
  @output_type_hash Crypto.hash(@output_encoded_type)

  @empty_input_hash "1a5933eb0b3223b0500fbbe7039cab9badc006adda6cf3d337751412fd7a4b61" |> Base.decode16!(case: :lower)
  @empty_output_hash "853a8d8af99c93405a791b97d57e819e538b06ffaa32ad70da2582500bc18d43" |> Base.decode16!(case: :lower)

  @doc """
  Computes a hash of encoded transaction as defined in EIP-712
  """
  @spec hash_struct(Transaction.t(), Crypto.domain_separator_t()) :: Crypto.hash_t()
  def hash_struct(raw_tx, domain_separator \\ nil) do
    Crypto.hash(<<0x19, 0x01>> <> (domain_separator || @domain_separator) <> hash_transaction(raw_tx))
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

  @spec hash_transaction(Transaction.t()) :: Crypto.hash_t()
  def hash_transaction(raw_tx) do
    input_hashes =
      Transaction.get_inputs(raw_tx)
      |> Stream.map(&hash_input/1)
      |> Stream.concat(Stream.cycle([@empty_input_hash]))
      |> Enum.take(Transaction.max_inputs())

    output_hashes =
      Transaction.get_outputs(raw_tx)
      |> Stream.map(&hash_output/1)
      |> Stream.concat(Stream.cycle([@empty_output_hash]))
      |> Enum.take(Transaction.max_outputs())

    [
      @transaction_type_hash,
      input_hashes,
      output_hashes,
      raw_tx.metadata || <<0::256>>
    ]
    |> List.flatten()
    |> Enum.join()
    |> Crypto.hash()
  end
end
