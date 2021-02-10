# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.Integration.Fixtures do
  use ExUnitFixtures.FixtureModule
  use OMG.Fixtures

  alias OMG.Eth.Encoding
  alias OMG.Eth.Token
  alias Support.DevHelper
  alias Support.Integration.DepositHelper

  deffixture alice_deposits(alice, token) do
    prepare_deposits(alice, token)
  end

  deffixture stable_alice_deposits(stable_alice, token) do
    prepare_deposits(stable_alice, token)
  end

  defp prepare_deposits(alice, token_addr) do
    some_value = 10

    {:ok, _} = DevHelper.import_unlock_fund(alice)

    deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, some_value)
    token_addr = Encoding.from_hex(token_addr, :mixed)
    {:ok, _} = Token.mint(alice.addr, some_value, token_addr) |> DevHelper.transact_sync!()
    token_deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, some_value, token_addr)

    {deposit_blknum, token_deposit_blknum}
  end
end
