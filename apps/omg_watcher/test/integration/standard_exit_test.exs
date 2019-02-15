# Copyright 2018 OmiseGO Pte Ltd
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
  use OMG.API.Fixtures
  use OMG.API.Integration.Fixtures
  use Plug.Test

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.API.Utxo
  alias OMG.Eth
  alias OMG.Watcher.TestHelper
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest

  require Utxo

  @moduletag :integration
  @moduletag timeout: 120_000

  @timeout 40_000
  @eth Crypto.zero_address()
  @encoded_eth Crypto.zero_address() |> Crypto.encode_address()

  @tag fixtures: [:watcher_sandbox, :stable_alice, :child_chain, :token, :stable_alice_deposits]
  test "exit finalizes", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    exit_period = Application.fetch_env!(:omg_eth, :exit_period_seconds)
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    %{"blknum" => tx_blknum} = TestHelper.submit(tx)

    IntegrationTest.wait_for_block_fetch(tx_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = TestHelper.get_exit_data(tx_blknum, 0, 0)

    {:ok, %{"status" => "0x1"}} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

      Process.sleep(2 * exit_period + 10)
      {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} = OMG.Eth.RootChain.process_exits(@eth, 0, 1, alice.addr) |> Eth.DevHelpers.transact_sync!()
      Eth.DevHelpers.wait_for_root_chain_block(eth_height + exit_finality_margin + 1)

      balance_post_exit = TestHelper.get_balance(alice.addr, @encoded_eth)
      assert balance_post_exit == 0
  end
end
