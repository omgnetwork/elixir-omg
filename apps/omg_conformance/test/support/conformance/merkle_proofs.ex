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

defmodule Support.Conformance.MerkleProofs do
  @moduledoc """
  Utility functions used when testing Elixir vs Solidity implementation conformance
  """

  alias OMG.Eth.Encoding

  @doc """
  Checks if the provided proof data returns true (valid proof) in the contract
  """
  def solidity_proof_valid(leaf, index, root_hash, proof, contract) do
    signature = "checkMembership(bytes,uint256,bytes32,bytes)"
    args = [leaf, index, root_hash, proof]
    return_types = [:bool]

    case call_contract(contract, signature, args, return_types) do
      {:error, _} -> false
      {:ok, result} -> result
    end
  end

  defp call_contract(contract, signature, args, return_types) do
    data = ABI.encode(signature, args)

    eth_call = %{
      from: Encoding.to_hex(contract),
      to: Encoding.to_hex(contract),
      data: Encoding.to_hex(data)
    }

    case Ethereumex.HttpClient.eth_call(eth_call) do
      {:ok, return} ->
        {:ok, decode_answer(return, return_types)}

      error ->
        error
    end
  end

  defp decode_answer(enc_return, return_types) do
    single_return =
      enc_return
      |> Encoding.from_hex()
      |> ABI.TypeDecoder.decode(return_types)
      |> hd()

    single_return
  end
end
