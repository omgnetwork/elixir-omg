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

defmodule OMG.Watcher.Integration.BlockGetterTest do
  @moduledoc """
  This test is intended to be the major smoke/integration test of the Watcher

  It tests whether valid/invalid blocks, deposits and exits are tracked correctly within the Watcher
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.Watcher.Integration.Fixtures
  use Plug.Test

  require OMG.Utxo

  alias OMG.Eth
  alias OMG.Eth.Support.BlockSubmission.Integration
  alias OMG.Watcher.BlockGetter
  alias OMG.Watcher.Event
  alias OMG.Watcher.Integration.BadChildChainServer
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.WatcherHelper

  @timeout 40_000
  @eth <<0::160>>

  @moduletag :integration
  @moduletag :watcher

  @moduletag timeout: 100_000

  @tag fixtures: [:in_beam_watcher, :test_server]
  test "hash of returned block does not match hash submitted to the root chain", %{test_server: context} do
    different_hash = <<0::256>>
    block_with_incorrect_hash = %{OMG.Block.hashed_txs_at([], 1000) | hash: different_hash}

    # from now on the child chain server is broken until end of test
    route =
      BadChildChainServer.prepare_route_to_inject_bad_block(
        context,
        block_with_incorrect_hash,
        different_hash
      )

    :sys.replace_state(BlockGetter, fn state ->
      config = state.config
      new_config = %{config | child_chain_url: "http://localhost:#{route.port}"}
      %{state | config: new_config}
    end)

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             {:ok, _txhash} = Integration.submit_block(different_hash, 0, 20_000_000_000)
             IntegrationTest.wait_for_byzantine_events([%Event.InvalidBlock{}.name], @timeout)
           end) =~ inspect({:error, :incorrect_hash})
  end

  @tag fixtures: [:in_beam_watcher, :alice, :test_server]
  test "bad transaction with not existing utxo, detected by interactions with State", %{
    alice: alice,
    test_server: context
  } do
    # preparing block with invalid transaction
    recovered = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    block_with_incorrect_transaction = OMG.Block.hashed_txs_at([recovered], 1000)

    # from now on the child chain server is broken until end of test
    route =
      BadChildChainServer.prepare_route_to_inject_bad_block(
        context,
        block_with_incorrect_transaction
      )

    :sys.replace_state(BlockGetter, fn state ->
      config = state.config
      new_config = %{config | child_chain_url: "http://localhost:#{route.port}"}
      %{state | config: new_config}
    end)

    invalid_block_hash = block_with_incorrect_transaction.hash

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             {:ok, _txhash} = Integration.submit_block(invalid_block_hash, 0, 20_000_000_000)
             IntegrationTest.wait_for_byzantine_events([%Event.InvalidBlock{}.name], @timeout)
           end) =~ inspect(:tx_execution)
  end
end
