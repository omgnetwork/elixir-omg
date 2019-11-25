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

defmodule OMG.Conformance.SignaturePropertyTest do
  @moduledoc """
  Checks if some properties about the signatures (structural, EIP-712 hashes to be precise) hold for the Elixir and
  Solidity implementations
  """

  # FIXME: unimport
  import Support.Conformance
  import Support.Conformance.Property

  use PropCheck
  use Support.Conformance.Case, async: false

  @moduletag :integration
  @moduletag :common
  @moduletag :property
  @moduletag timeout: 450_000

  property "any tx hashes/signhashes the same in all implementations",
           [1000, :verbose, max_size: 100, constraint_tries: 100_000],
           %{contract: contract} do
    forall tx <- payment_tx() do
      # FIXME: expand somewhere with verifying the non-signature-related hash, Transaction.raw_txhash
      verify(contract, tx)
    end
  end

  property "any 2 different txs hash/signhash differently, regardless of implementation",
           [1000, :verbose, max_size: 100, constraint_tries: 100_000],
           %{contract: contract} do
    forall [{tx1, tx2} <- distinct_payment_txs()] do
      # FIXME: expand somewhere with verifying the non-signature-related hash, Transaction.raw_txhash
      verify_distinct(contract, tx1, tx2)
    end
  end

  property "any crude-mutated tx binary either fails to decode to a transaction object or is recognized as different",
           [1000, :verbose, max_size: 100, constraint_tries: 100_000],
           %{contract: contract} do
    forall {_tx1_binary, tx2_binary} <- tx_binary_with_mutation() do
      decoding_errors_the_same(contract, tx2_binary)
      # FIXME: return to this - this reasoning must be reworked - how do we phrase the condition here?
      # ||
      #           verify_distinct(
      #             contract,
      # FIXME: can we ever hope to fall into this clause?
      #   IO.inspect(Transaction.decode!(tx1_binary)),
      #   IO.inspect(Transaction.decode!(tx2_binary))
      # )
    end
  end

  # FIXME: remove work tag
  @tag :work
  property "any rlp-mutated tx binary either fails to decode to a transaction object or is recognized as different",
           [1000, :verbose, max_size: 100, constraint_tries: 100_000],
           %{contract: contract} do
    forall {_tx1_binary, tx2_binary} <- tx_binary_with_rlp_mutation() do
      decoding_errors_the_same_rlp_mutated(contract, tx2_binary)
      # FIXME: return to this - this reasoning must be reworked - how do we phrase the condition here?
      # ||
      #   verify_distinct(
      #     contract,
      # FIXME: can we ever hope to fall into this clause?
      #   IO.inspect(Transaction.decode!(tx1_binary)),
      #   IO.inspect(Transaction.decode!(tx2_binary))
      # )
    end
  end

  property "arbitrary binaries never decode",
           [1000, :verbose, max_size: 1000],
           %{contract: contract} do
    forall some_binary <- binary() do
      decoding_errors_the_same(contract, some_binary)
    end
  end

  defp decoding_errors_the_same(contract, some_binary) do
    elixir_decoding_errors = [
      {:error, :malformed_transaction_rlp},
      {:error, :malformed_inputs},
      {:error, :malformed_outputs},
      {:error, :malformed_transaction}
    ]

    solidity_decoding_errors = [
      "Item is not a list",
      "Invalid encoding of transaction",
      "Decoded RLP length for list is invalid",
      "Invalid RLP encoding",
      "Invalid decoded length of RLP item found during counting items in a list"
    ]

    verify_both_error(contract, some_binary, elixir_decoding_errors, solidity_decoding_errors)
  end

  defp decoding_errors_the_same_rlp_mutated(contract, some_binary) do
    elixir_decoding_errors = [
      {:error, :malformed_inputs},
      {:error, :malformed_outputs},
      {:error, :malformed_transaction}
    ]

    solidity_decoding_errors = ["Invalid encoding of transaction"]

    verify_both_error(contract, some_binary, elixir_decoding_errors, solidity_decoding_errors)
  end
end
