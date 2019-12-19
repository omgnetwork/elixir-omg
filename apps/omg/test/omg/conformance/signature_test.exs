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

  alias OMG.State.Transaction

  # FIXME: unimport
  import Support.Conformance

  alias OMG.State.Transaction

  use Support.Conformance.Case, async: false

  @moduletag :integration
  @moduletag :common

  @good_tx_data 0
  @good_metadata <<1::size(32)-unit(8)>>
  @good_address <<1::size(20)-unit(8)>>
  @good_amount <<1>>

  describe "elixir vs solidity conformance test" do
    test "no inputs test", %{contract: contract} do
      tx = Transaction.Payment.new([], [{@alice, @eth, 100}])
      verify(tx, contract)
    end

    test "signature test - small tx", %{contract: contract} do
      tx = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}])
      verify(tx, contract)
    end

    test "signature test - full tx", %{contract: contract} do
      tx =
        Transaction.Payment.new(
          [{1, 0, 0}, {1000, 555, 3}, {2000, 333, 1}, {15_015, 0, 0}],
          [{@alice, @eth, 100}, {@alice, @token, 50}, {@bob, @token, 75}, {@bob, @eth, 25}]
        )

      verify(tx, contract)
    end

    test "signature test transaction with metadata", %{contract: contract} do
      tx =
        Transaction.Payment.new(
          [{1, 0, 0}, {1000, 555, 3}, {2000, 333, 1}, {15_015, 0, 0}],
          [{@alice, @eth, 100}, {@alice, @eth, 50}, {@bob, @eth, 75}, {@bob, @eth, 25}],
          @good_metadata
        )

      verify(tx, contract)
    end

    test "unrecognized output type", %{contract: contract} do
      # FIXME: remove and change into a pair of pure elixir test and solc test
      unrecognized_output = [234_567, [@good_address, @good_address, @good_amount]]
      txbytes = ExRLP.encode([1, [], [unrecognized_output], @good_tx_data, @good_metadata])

      verify_both_error(txbytes, contract)
    end

    test "unrecognized tx type", %{contract: contract} do
      # FIXME: remove and change into a pair of pure elixir test and solc test
      txbytes =
        ExRLP.encode([234_567, [], [[1, [@good_address, @good_address, @good_amount]]], @good_tx_data, @good_metadata])

      verify_both_error(txbytes, contract)
    end
  end

  describe "distinct transactions yield distinct sign hashes" do
    test "different inputs - txs hash differently but same in both implementations", %{contract: contract} do
      tx1 = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}])
      tx2 = Transaction.Payment.new([{2, 0, 0}], [{@alice, @eth, 100}])
      verify_distinct(tx1, tx2, contract)
    end

    test "different outputs - txs hash differently but same in both implementations", %{contract: contract} do
      tx1 = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 110}])
      tx2 = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}])
      verify_distinct(tx1, tx2, contract)
    end

    test "different metadata - txs hash differently but same in both implementations", %{contract: contract} do
      tx1 = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}])
      tx2 = Transaction.Payment.new([{1, 0, 0}], [{@alice, @eth, 100}], <<1::256>>)
      verify_distinct(tx1, tx2, contract)
    end
  end
end
