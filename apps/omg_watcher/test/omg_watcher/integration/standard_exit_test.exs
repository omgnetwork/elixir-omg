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

defmodule OMG.Watcher.Integration.StandardExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  # TODO REMOVE childchain fixtures in watcher
  use OMG.ChildChain.Integration.Fixtures
  use Plug.Test

  alias OMG.Utxo
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WatcherHelper

  require Utxo

  @moduletag :integration
  @moduletag :watcher
  @moduletag timeout: 180_000

  @timeout 40_000
  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:in_beam_watcher, :stable_alice, :mix_based_child_chain, :token, :stable_alice_deposits]
  test "exit finalizes", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    %{"blknum" => tx_blknum} = WatcherHelper.submit(tx)

    IntegrationTest.wait_for_block_fetch(tx_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = WatcherHelper.get_exit_data(tx_blknum, 0, 0)

    {:ok, %{"status" => "0x1"}} =
      DevHelper.transact_sync!(RootChainHelper.start_exit(utxo_pos, txbytes, proof, alice.addr))

    :ok = IntegrationTest.process_exits(1, @eth, alice)
  end
end
