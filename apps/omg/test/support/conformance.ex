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

  import ExUnit.Assertions

  def verify_distinct(tx1, tx2, contract) do
    # NOTE: those two verifies might be redundant, rethink sometimes. For now keeping to increase chance of picking up
    # discrepancies
    verify(tx1, contract)
    verify(tx2, contract)
    assert solidity_hash!(tx1, contract) != solidity_hash!(tx2, contract)
    assert elixir_hash(tx1) != elixir_hash(tx2)
  end

  def verify(tx, contract) do
    assert solidity_hash!(tx, contract) == elixir_hash(tx)
  end

  def verify_both_error(some_binary, contract) do
    # elixir implementation errors
    assert {:error, _} = Transaction.decode(some_binary)

    # solidity implementation errors
    some_binary
    |> solidity_hash(contract)
    |> assert_contract_reverted()

    true
  end

  defp solidity_hash!(tx, contract) do
    {:ok, solidity_hash} = solidity_hash(tx, contract)
    solidity_hash
  end

  defp solidity_hash(%{} = tx, contract), do: solidity_hash(Transaction.raw_txbytes(tx), contract)

  defp solidity_hash(encoded_tx, contract) when is_binary(encoded_tx),
    do: Eth.call_contract(contract, "hashTx(address,bytes)", [contract, encoded_tx], [{:bytes, 32}])

  defp elixir_hash(%Transaction.Signed{raw_tx: tx}), do: OMG.TypedDataHash.hash_struct(tx)
  defp elixir_hash(tx), do: OMG.TypedDataHash.hash_struct(tx)

  defp assert_contract_reverted(result) do
    Application.fetch_env!(:omg_eth, :eth_node)
    |> case do
      :ganache ->
        assert {:error, %{"data" => error_data}} = result
        # NOTE one can use the "reason" field in here to make sure what caused the revert. Only with ganache
        assert [%{"error" => "revert"} | _] = Map.values(error_data)

      :geth ->
        # `geth` is problematic - on a revert from `Eth.call_contract` it returns something resembling a reason
        # binary (beginning with 4-byte function selector). We need to assume that this is in fact a revert
        assert {:ok, chopped_reason_binary_result} = result
        assert <<0::size(28)-unit(8)>> = binary_part(chopped_reason_binary_result, 4, 28)
    end
  end
end
