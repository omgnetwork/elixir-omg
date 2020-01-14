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

defmodule OMG.Conformance.SignaturePropertyTest do
  @moduledoc """
  Checks if some properties about the signatures (structural, EIP-712 hashes to be precise) hold for the Elixir and
  Solidity implementations
  """

  alias Support.Conformance.PropertyGenerators

  import Support.Conformance,
    only: [verify: 2, verify_distinct: 3, verify_both_error: 2, verify_distinct_or_erroring: 3]

  use PropCheck
  use Support.Conformance.Case, async: false

  @moduletag :property
  @moduletag timeout: 450_000

  property "any tx hashes/signhashes the same in all implementations",
           [1000, :verbose, max_size: 100, constraint_tries: 100_000],
           %{contract: contract} do
    forall tx <- PropertyGenerators.payment_tx() do
      # TODO: expand with verifying the non-signature-related hash, Transaction.raw_txhash
      #       This occurs multiple times, wherever transaction/implementation identity/conformance is tested
      verify(tx, contract)
    end
  end

  property "any 2 different txs hash/signhash differently, regardless of implementation",
           [1000, :verbose, max_size: 100, constraint_tries: 100_000],
           %{contract: contract} do
    forall [{tx1, tx2} <- PropertyGenerators.distinct_payment_txs()] do
      verify_distinct(tx1, tx2, contract)
    end
  end

  property "any crude-mutated tx binary either fails to decode to a transaction object or is recognized as different",
           [1000, :verbose, max_size: 100, constraint_tries: 100_000],
           %{contract: contract} do
    forall {tx1_binary, tx2_binary} <- PropertyGenerators.tx_binary_with_mutation() do
      verify_distinct_or_erroring(tx1_binary, tx2_binary, contract)
    end
  end

  # this is by far the most interesting-case-yielding test, hence number of cases is set to x10 the others
  property "any rlp-mutated tx binary either fails to decode to a transaction object or is recognized as different",
           [10_000, :verbose, max_size: 100, constraint_tries: 100_000],
           %{contract: contract} do
    forall {tx1_binary, tx2_binary} <- PropertyGenerators.tx_binary_with_rlp_mutation() do
      verify_distinct_or_erroring(tx1_binary, tx2_binary, contract)
    end
  end

  property "arbitrary binaries never decode",
           [1000, :verbose, max_size: 1000],
           %{contract: contract} do
    forall some_binary <- binary() do
      verify_both_error(some_binary, contract)
    end
  end
end
