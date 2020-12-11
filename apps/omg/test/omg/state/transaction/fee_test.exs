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

defmodule OMG.State.Transaction.FeeTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.State.Transaction

  @eth OMG.Eth.zero_address()
  @other_token <<127::160>>

  setup do
    {:ok, [alice: OMG.TestHelper.generate_entity()]}
  end

  describe "new/2" do
    test "can be encoded to binary form and back", %{alice: owner} do
      fee_tx = Transaction.Fee.new(1000, {owner.addr, @eth, 1551})

      rlp_form = Transaction.raw_txbytes(fee_tx)
      assert fee_tx == Transaction.decode!(rlp_form)
    end

    test "hash can be computed with protocol implementation", %{alice: owner} do
      fee_tx = Transaction.Fee.new(1000, {owner.addr, @eth, 1551})
      fee_txhash = Transaction.raw_txhash(fee_tx)
      assert <<_::256>> = fee_txhash

      assert Transaction.raw_txhash(Transaction.Fee.new(1000, {owner.addr, @eth, 1551})) == fee_txhash
      assert Transaction.raw_txhash(Transaction.Fee.new(1001, {owner.addr, @eth, 1551})) != fee_txhash
      assert Transaction.raw_txhash(Transaction.Fee.new(1000, {owner.addr, @other_token, 1551})) != fee_txhash
    end

    test "fee-tx should be recoverable from binary form", %{alice: owner} do
      fee_tx = Transaction.Fee.new(1000, {owner.addr, @eth, 1551})
      tx_rlp = Transaction.Signed.encode(%Transaction.Signed{raw_tx: fee_tx, sigs: []})

      assert {:ok,
              %Transaction.Recovered{
                signed_tx: %Transaction.Signed{raw_tx: ^fee_tx}
              }} = Transaction.Recovered.recover_from(tx_rlp)
    end
  end
end
