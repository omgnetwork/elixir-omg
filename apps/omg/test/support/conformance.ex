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

# FIXME: rename and move to Support.Conformance.SignaturesHashes
defmodule Support.Conformance do
  @moduledoc """
  Utility functions that used when testing Elixir vs Solidity implementation conformance
  """
  alias OMG.Eth
  alias OMG.State.Transaction

  import ExUnit.Assertions, only: [assert: 1, assert: 2]

  @doc """
  Check if both implementations treat distinct transactions as distinct but produce sign hashes consistently
  """
  def verify_distinct(tx1, tx2, contract) do
    # NOTE: those two verifies might be redundant, rethink sometimes. For now keeping to increase chance of picking up
    # discrepancies
    verify(tx1, contract)
    verify(tx2, contract)
    assert solidity_hash!(tx1, contract) != solidity_hash!(tx2, contract)
    assert elixir_hash(tx1) != elixir_hash(tx2)
  end

  @doc """
  Check if both implementations product the same signature hash
  """
  def verify(tx, contract) do
    assert solidity_hash!(tx, contract) == elixir_hash(tx)
  end

  @doc """
  Check if both implementations error for a binary that's known to not be a validly decoding transaction
  """
  def verify_both_error(some_binary, contract) do
    # elixir implementation errors
    assert {:error, _} = Transaction.decode(some_binary)

    # solidity implementation errors
    some_binary
    |> solidity_hash(contract)
    |> assert_contract_reverted()

    true
  end

  @doc """
  Check if both implementations either:
    - treat distinct transactions as distinct but produce sign hashes consistently
    - both error
  _under the condition that `tx2_binary` decodes fine in the "native" implementation in Elixir_
  """
  def verify_distinct_or_erroring(tx1_binary, tx2_binary, contract) do
    # TODO - think of a better approach to handling the different treatment of valid/admissible tx/output types
    #      there shouldn't be that many cases, 2 (`{:ok, _}` and `{:error, _}`) should ideally do
    case Transaction.decode(tx2_binary) do
      # if the mutated transaction decodes fine, we check whether signature hashes match across impls and are distinct
      {:ok, _} ->
        verify_distinct(Transaction.decode!(tx1_binary), Transaction.decode!(tx2_binary), contract)

      # NOTE: unrecognized tx/output type is never picked up in the contract, since there, decoding assumes already a
      #       particular type (i.e. Payment) and only checks if delivered type (`1`, `2`, ...) is correct in later stage
      #       when fetching and verifying the `ISpendingCondition`
      {:error, :unrecognized_transaction_type} ->
        true

      {:error, :unrecognized_output_type} ->
        true

      # NOTE: another temporary special case handling, until a better idea comes. `tx_type` 3 is `FeeTokenClaim`
      #       transaction which pops out as `malformed` in `elixir-omg` and is accepted by contracts
      {:error, :malformed_transaction} ->
        case ExRLP.decode(tx2_binary) do
          # first RLP item of the transaction specifies the tx type as `FeeTokenClaim` - can't test further
          [<<3>> | _] -> true
          # in all other cases the contract should revert
          _ -> verify_both_error(tx2_binary, contract)
        end

      # in other cases of errors, we check whether both implementations reject the mutated transaction
      {:error, _} ->
        verify_both_error(tx2_binary, contract)
    end
  end

  defp solidity_hash!(tx, contract) do
    {:ok, solidity_hash} = solidity_hash(tx, contract)
    solidity_hash
  end

  defp solidity_hash(%{} = tx, contract), do: tx |> Transaction.raw_txbytes() |> solidity_hash(contract)

  defp solidity_hash(encoded_tx, contract) when is_binary(encoded_tx),
    do: Eth.call_contract(contract, "hashTx(address,bytes)", [contract, encoded_tx], [{:bytes, 32}])

  defp elixir_hash(%{} = tx), do: OMG.TypedDataHash.hash_struct(tx)
  defp elixir_hash(encoded_tx), do: encoded_tx |> Transaction.decode!() |> elixir_hash()

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
