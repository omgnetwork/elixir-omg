# Copyright 2019-2020 OmiseGO Pte Ltd
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

  import ExUnit.Assertions, only: [assert: 1]

  alias OMG.Eth.Encoding

  @doc """
  Checks if the provided proof data returns true (valid proof) in the contract
  """
  def solidity_proof_valid(leaf, index, root_hash, proof, contract) do
    signature = "checkMembership(bytes,uint256,bytes32,bytes)"
    args = [leaf, index, root_hash, proof]
    return_types = [:bool]

    try do
      {:ok, result} = call_contract(contract, signature, args, return_types)
      result
      # Some incorrect proofs throw, and end up returning something that the ABI decoder borks on, hence rescue
    rescue
      e in CaseClauseError ->
        # this term holds the failure reason, but attempted to be decoded as a bool. It is a huge int
        %{term: failed_decoding_reason} = e
        # now we bring it back to binary form
        binary_reason = :binary.encode_unsigned(failed_decoding_reason)
        # it should contain 4 bytes of the function selector and then zeros
        assert_contract_reverted(binary_reason)
        false
    end
  end

  # see similar function in `Support.Conformance.SignaturesHashes`
  defp assert_contract_reverted(chopped_reason_binary_result) do
    # only geth is supported for the merkle proof conformance tests for now
    :geth = Application.fetch_env!(:omg_eth, :eth_node)

    # revert from `call_contract` it returns something resembling a reason
    # binary (beginning with 4-byte function selector). We need to assume that this is in fact a revert
    assert <<0::size(28)-unit(8)>> = binary_part(chopped_reason_binary_result, 4, 28)
  end

  defp call_contract(contract, signature, args, return_types) do
    data = ABI.encode(signature, args)

    {:ok, return} =
      Ethereumex.HttpClient.eth_call(%{
        from: Encoding.to_hex(contract),
        to: Encoding.to_hex(contract),
        data: Encoding.to_hex(data)
      })

    decode_answer(return, return_types)
  end

  defp decode_answer(enc_return, return_types) do
    single_return =
      enc_return
      |> Encoding.from_hex()
      |> ABI.TypeDecoder.decode(return_types)
      |> hd()

    {:ok, single_return}
  end
end
