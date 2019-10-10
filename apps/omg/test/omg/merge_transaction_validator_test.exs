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

defmodule OMG.MergeTransactionValidatorTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  import OMG.TestHelper

  alias OMG.MergeTransactionValidator
  alias OMG.State.Transaction

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @not_eth <<1::size(160)>>

  describe "is_merge_transaction?/1" do
    @tag fixtures: [:alice]
    test "returns true when the transaction is a payment, has less outputs than inputs, has single currency, and has same account",
         %{alice: alice} do
      transaction = create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], @eth, [{alice, 10}])
      assert MergeTransactionValidator.is_merge_transaction?(transaction)
    end

    test "returns false when transaction is not of payment type" do
      refute MergeTransactionValidator.is_merge_transaction?(%Transaction.Recovered{signed_tx: %{raw_tx: "fake"}})
    end

    test "returns false when transaction doesn't consist of fungible-tokens only" do
      refute MergeTransactionValidator.is_merge_transaction?(%Transaction.Recovered{
               signed_tx: %Transaction.Signed{raw_tx: %Transaction.Payment{inputs: [1, 2], outputs: [%{}]}}
             })
    end

    @tag fixtures: [:alice]
    test "returns false when transaction has as many outputs than inputs", %{alice: alice} do
      transaction = create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], @eth, [{alice, 5}, {alice, 5}])
      refute MergeTransactionValidator.is_merge_transaction?(transaction)
    end

    @tag fixtures: [:alice]
    test "returns false when transaction has more outputs than inputs", %{alice: alice} do
      transaction = create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], @eth, [{alice, 3}, {alice, 3}, {alice, 4}])
      refute MergeTransactionValidator.is_merge_transaction?(transaction)
    end

    @tag fixtures: [:alice]
    test "returns false when not a single currency", %{alice: alice} do
      transaction =
        create_recovered(
          [{1, 0, 0, alice}, {1, 0, 1, alice}, {2, 0, 0, alice}, {2, 1, 0, alice}],
          [{alice, @eth, 10}, {alice, @not_eth, 10}]
        )

      refute MergeTransactionValidator.is_merge_transaction?(transaction)
    end

    @tag fixtures: [:alice, :bob]
    test "returns false when two different accounts in outputs", %{alice: alice, bob: bob} do
      transaction =
        create_recovered([{1, 0, 0, alice}, {1, 0, 1, alice}, {2, 0, 0, alice}], @eth, [{bob, 10}, {alice, 10}])

      refute MergeTransactionValidator.is_merge_transaction?(transaction)
    end
  end
end
