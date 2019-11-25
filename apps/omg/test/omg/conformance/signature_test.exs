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

defmodule OMG.Conformance.SignatureTest do
  @moduledoc """
  Tests that EIP-712-compliant signatures generated `somehow` (via Elixir code as it happens) are treated the same
  by both Elixir signature code and contract signature code.
  """

  # FIXME: unimport
  import Support.Conformance

  alias OMG.State.Transaction

  use Support.Conformance.Case, async: false

  @moduletag :integration
  @moduletag :common

  describe "elixir vs solidity conformance test" do
    test "no inputs test", %{contract: contract} do
      tx = Transaction.Payment.new([], [{@alice, @eth, 100}])
      verify(contract, tx)
    end

    test "signature test - small tx", %{contract: contract} do
      tx = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}])
      verify(contract, tx)
    end

    test "signature test - full tx", %{contract: contract} do
      tx =
        Transaction.Payment.new(
          [{1, 0, 0}, {1000, 555, 3}, {2000, 333, 1}, {15_015, 0, 0}],
          [{@alice, @eth, 100}, {@alice, @token, 50}, {@bob, @token, 75}, {@bob, @eth, 25}]
        )

      verify(contract, tx)
    end

    test "signature test transaction with metadata", %{contract: contract} do
      {:ok, <<_::256>> = metadata} = DevCrypto.generate_private_key()

      tx =
        Transaction.Payment.new(
          [{1, 0, 0}, {1000, 555, 3}, {2000, 333, 1}, {15_015, 0, 0}],
          [{@alice, @eth, 100}, {@alice, @eth, 50}, {@bob, @eth, 75}, {@bob, @eth, 25}],
          metadata
        )

      verify(contract, tx)
    end

    test "signature test, transaction with zero output amount", %{contract: contract} do
      tx = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}, {<<1::160>>, @zero_address, 0}])
      verify(contract, tx)
    end

    test "signature test, transaction with an explicit zero output", %{contract: contract} do
      tx = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}, {@zero_address, @zero_address, 0}])
      verify(contract, tx)
    end

    test "signature test, transaction with an explicit zero input", %{contract: contract} do
      tx = Transaction.Payment.new([{1, 0, 0}, {0, 0, 0}], [{@alice, @eth, 100}])
      verify(contract, tx)
    end
  end

  # FIXME: this might not belong here, technically speaking it could cover the same stuff if put in `plasma_contracts`
  describe "distinct transactions yield distinct sign hashes" do
    test "sanity check - different txs hash differently", %{contract: contract} do
      tx1 = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}])
      tx2 = Transaction.Payment.new([{2, 0, 0}], [{@alice, @eth, 100}])
      verify_distinct(contract, tx1, tx2)
    end

    test "explicit zero input alters sign hash", %{contract: contract} do
      tx1 = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}])
      tx2 = Transaction.Payment.new([{1, 0, 0}, {0, 0, 0}], [{@alice, @eth, 100}])
      verify_distinct(contract, tx1, tx2)
    end

    test "explicit zero outputs alters sign hash", %{contract: contract} do
      tx1 = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}])
      tx2 = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}, {@zero_address, @zero_address, 0}])
      verify_distinct(contract, tx1, tx2)
    end
  end
end
