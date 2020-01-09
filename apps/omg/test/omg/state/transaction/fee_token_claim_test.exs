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

defmodule OMG.State.Transaction.FeeTokenClaimTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Output
  alias OMG.State.Transaction

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @other_token <<127::160>>

  describe "new/2" do
    @tag fixtures: [:alice]
    test "can be encoded to binary form and back", %{alice: owner} do
      fee_tx = Transaction.FeeTokenClaim.new(1000, {owner.addr, @eth, 1551})

      rlp_form = Transaction.raw_txbytes(fee_tx)
      assert fee_tx == Transaction.decode!(rlp_form)
    end

    @tag fixtures: [:alice]
    test "hash can be computed with protocol implementation", %{alice: owner} do
      fee_tx = Transaction.FeeTokenClaim.new(1000, {owner.addr, @eth, 1551})
      fee_txhash = Transaction.raw_txhash(fee_tx)
      assert <<_::256>> = fee_txhash

      assert Transaction.raw_txhash(Transaction.FeeTokenClaim.new(1000, {owner.addr, @eth, 1551})) == fee_txhash
      assert Transaction.raw_txhash(Transaction.FeeTokenClaim.new(1001, {owner.addr, @eth, 1551})) != fee_txhash
      assert Transaction.raw_txhash(Transaction.FeeTokenClaim.new(1000, {owner.addr, @other_token, 1551})) != fee_txhash
    end

    # FIXME: Fee-tx should be recoverable and executable on state but CANNOT be accepted by submit (tests needed)
    @tag fixtures: [:alice]
    test "fee-tx should be recoverable from binary form", %{alice: owner} do
      fee_tx = Transaction.FeeTokenClaim.new(1000, {owner.addr, @eth, 1551})
      tx_rlp = Transaction.Signed.encode(%Transaction.Signed{raw_tx: fee_tx, sigs: []})

      assert {:ok,
              %Transaction.Recovered{
                signed_tx: %Transaction.Signed{raw_tx: ^fee_tx}
              }} = Transaction.Recovered.recover_from(tx_rlp)
    end
  end

  describe "claim_collected/3" do
    @tag fixtures: [:alice]
    test "no fees collected result in empty fee-txs list", %{alice: owner} do
      assert [] == Transaction.FeeTokenClaim.claim_collected(1000, owner, %{})
    end

    @tag fixtures: [:alice]
    test "fee-txs are sorted by currency", %{alice: owner} do
      fees_paid = %{
        @other_token => 111,
        @eth => 100
      }

      assert [
               eth_fee_tx,
               other_fee_tx
             ] = Transaction.FeeTokenClaim.claim_collected(1000, owner, fees_paid)

      assert [
               %Output{
                 owner: ^owner,
                 currency: @eth,
                 amount: 100
               }
             ] = Transaction.get_outputs(eth_fee_tx)

      assert [
               %Output{
                 owner: ^owner,
                 currency: @other_token,
                 amount: 111
               }
             ] = Transaction.get_outputs(other_fee_tx)
    end
  end
end
