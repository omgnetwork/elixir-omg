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

defmodule OMG.Performance.ByzantineEvents.TransactionCreatorTest do
  use ExUnit.Case, async: true

  alias OMG.Performance.ByzantineEvents.TransactionCreator
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  setup do
    alice = OMG.TestHelper.generate_entity()
    {:ok, %{alice: alice}}
  end

  describe "spend_utxo_by" do
    test "should create a well signed transaction from an owner", %{alice: alice} do
      encoded_tx = TransactionCreator.spend_utxo_by(100_000_000_000_000, alice.addr, alice.priv, 1)
      assert {:ok, %Transaction.Recovered{}} = Transaction.Recovered.recover_from(encoded_tx)
    end

    test "should accept a decoded utxo position", %{alice: alice} do
      encoded_tx = TransactionCreator.spend_utxo_by(Utxo.position(1_000_000, 4, 5), alice.addr, alice.priv, 1)
      assert {:ok, %Transaction.Recovered{}} = Transaction.Recovered.recover_from(encoded_tx)
    end
  end
end
