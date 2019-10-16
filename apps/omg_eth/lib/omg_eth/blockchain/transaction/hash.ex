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

defmodule Eth.Blockchain.Transaction.Hash do
  @moduledoc """
  Defines helper functions for signing and getting the signature
  of a transaction, as defined in Appendix F of the Yellow Paper.

  For any of the following functions, if chain_id is specified,
  it's assumed that we're post-fork and we should follow the
  specification EIP-155 from:

  https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
  Extracted from: https://github.com/exthereum/blockchain
  """

  alias Eth.Blockchain.BitHelper
  alias Eth.Blockchain.Transaction

  @doc """
  Returns a hash of a given transaction according to the
  formula defined in Eq.(214) and Eq.(215) of the Yellow Paper.

  Note: As per EIP-155 (https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md),
        we will append the chain-id and nil elements to the serialized transaction.

  ## Examples

      iex> Eth.Blockchain.Transaction.Hash.transaction_hash(%Eth.Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 5, init: <<1>>})
      <<127, 113, 209, 76, 19, 196, 2, 206, 19, 198, 240, 99, 184, 62, 8, 95, 9, 122, 135, 142, 51, 22, 61, 97, 70, 206, 206, 39, 121, 54, 83, 27>>

      iex> Eth.Blockchain.Transaction.Hash.transaction_hash(%Eth.Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1>>, value: 5, data: <<1>>})
      <<225, 195, 128, 181, 3, 211, 32, 231, 34, 10, 166, 198, 153, 71, 210, 118, 51, 117, 22, 242, 87, 212, 229, 37, 71, 226, 150, 160, 50, 203, 127, 180>>

      iex> Eth.Blockchain.Transaction.Hash.transaction_hash(%Eth.Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1>>, value: 5, data: <<1>>}, 1)
      <<132, 79, 28, 4, 212, 58, 235, 38, 66, 211, 167, 102, 36, 58, 229, 88, 238, 251, 153, 23, 121, 163, 212, 64, 83, 111, 200, 206, 54, 43, 112, 53>>
  """

  @spec transaction_hash(Transaction.t(), integer() | nil) :: BitHelper.keccak_hash()
  def transaction_hash(trx, chain_id \\ nil) do
    Transaction.serialize(trx, false)
    # See EIP-155
    |> Kernel.++(if chain_id, do: [:binary.encode_unsigned(chain_id), <<>>, <<>>], else: [])
    |> ExRLP.encode()
    |> BitHelper.kec()
  end
end
