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

defmodule OMG.State.Transaction.FeeTokenClaimTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.State.Transaction

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @other_token <<127::160>>

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

  @tag fixtures: [:alice]
  test "cannot be recovered in payment scenario", %{alice: owner} do
    fee_tx = Transaction.FeeTokenClaim.new(1000, {owner.addr, @eth, 1551})
    tx_rlp = Transaction.Signed.encode(%Transaction.Signed{raw_tx: fee_tx, sigs: []})

    assert {:error, :not_implemented} = Transaction.Recovered.recover_from(tx_rlp)
  end
end
