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

defmodule Support.Conformance do
  @moduledoc """
  Utility functions that used when testing Elixir vs Solidity implementation conformance
  """
  alias OMG.Eth
  alias OMG.State.Transaction
  alias OMG.TypedDataHash

  import ExUnit.Assertions

  def verify_distinct(contract, tx1, tx2) do
    # NOTE: those two verifies might be redundant, rethink sometimes. For now keeping to increase chance of picking up
    # discrepancies
    verify(contract, tx1)
    verify(contract, tx2)
    assert solidity_hash!(contract, tx1) != solidity_hash!(contract, tx2)
    assert elixir_hash(tx1) != elixir_hash(tx2)
  end

  def verify(contract, tx) do
    assert solidity_hash!(contract, tx) == elixir_hash(tx)
  end

  def verify_both_error(contract, some_binary, elixir_decoding_errors, solidity_decoding_errors) do
    assert Transaction.decode(some_binary) in elixir_decoding_errors
    assert (solidity_hash(contract, some_binary) |> get_reason_from_call()) in solidity_decoding_errors
  end

  defp solidity_hash!(contract, tx) do
    {:ok, solidity_hash} = solidity_hash(contract, tx)
    solidity_hash
  end

  defp solidity_hash(contract, %{} = tx), do: solidity_hash(contract, Transaction.raw_txbytes(tx))

  defp solidity_hash(contract, encoded_tx) when is_binary(encoded_tx),
    do: Eth.call_contract(contract, "hashTx(address,bytes)", [contract, encoded_tx], [{:bytes, 32}])

  defp elixir_hash(%Transaction.Signed{raw_tx: tx}), do: OMG.TypedDataHash.hash_struct(tx)
  defp elixir_hash(tx), do: TypedDataHash.hash_struct(tx)

  # FIXME: for some reason works for ganache only; for geth failures manifest as a binary with 4 non-zero bytes there
  #        in an ":ok" message. Investigate
  defp get_reason_from_call({:error, error_body}),
    do: error_body["data"] |> Map.values() |> Enum.at(0) |> Access.get("reason")
end
