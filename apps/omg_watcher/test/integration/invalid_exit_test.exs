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

defmodule OMG.Watcher.Integration.InvalidExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use OMG.API.Integration.Fixtures
  use Plug.Test

  alias OMG.API
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Eth
  alias OMG.RPC.Client
  alias OMG.Watcher
  alias OMG.Watcher.{Event, TestHelper}
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest

  import ExUnit.CaptureLog

  @moduletag :integration

  @timeout 40_000
  @eth API.Crypto.zero_address()

  @tag fixtures: [:watcher_sandbox, :stable_alice, :child_chain, :token, :stable_alice_deposits]
  test "exit which is using already spent utxo from transaction causes to emit invalid_exit event", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: deposit_blknum}} = Client.submit(tx)

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: tx_blknum, txhash: _tx_hash}} = Client.submit(tx)

    IntegrationTest.wait_for_block_fetch(tx_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = TestHelper.get_exit_data(deposit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => _eth_height}} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    IntegrationTest.wait_for_byzantine_events([%Event.InvalidExit{}.name], @timeout)

    # after the notification has been received, a challenged is composed and sent
    challenge = TestHelper.get_exit_challenge(deposit_blknum, 0, 0)
    {:ok, exit_id} = Eth.RootChain.get_standard_exit_id(utxo_pos)
    assert {:ok, {alice.addr, @eth, 10}} == Eth.RootChain.get_exit(exit_id)

    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChain.challenge_exit(
        challenge["output_id"],
        challenge["txbytes"],
        challenge["input_index"],
        challenge["sig"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    assert {:ok, {API.Crypto.zero_address(), @eth, 0}} == Eth.RootChain.get_exit(utxo_pos)

    IntegrationTest.wait_for_byzantine_events([], @timeout)
  end

  @tag fixtures: [:watcher_sandbox, :stable_alice, :child_chain, :token, :stable_alice_deposits, :test_server]
  test "transaction which is using already spent utxo from exit and happened before end of margin of slow validator (m_sv) causes to emit invalid_exit event ",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}, test_server: context} do
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: exit_blknum}} = Client.submit(tx)

    # Here we're preparing invalid block
    bad_block_number = 2_000
    bad_tx = API.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], @eth, [{alice, 10}])

    %{hash: bad_block_hash, number: _, transactions: _} =
      bad_block = API.Block.hashed_txs_at([bad_tx], bad_block_number)

    # from now on the child chain server is broken until end of test
    Watcher.Integration.BadChildChainServer.prepare_route_to_inject_bad_block(context, bad_block)

    IntegrationTest.wait_for_block_fetch(exit_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = TestHelper.get_exit_data(exit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => _eth_height}} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    # Here we're manually submitting invalid block to the root chain
    # NOTE: this **must** come after `start_exit` is mined (see just above) but still not later than
    #       `sla_margin` after exit start, hence the `config/test.exs` entry for the margin is rather high
    {:ok, _} = OMG.Eth.RootChain.submit_block(bad_block_hash, 2, 1)

    IntegrationTest.wait_for_byzantine_events([%Event.InvalidExit{}.name], @timeout)
  end

  @tag fixtures: [:watcher_sandbox, :stable_alice, :child_chain, :token, :stable_alice_deposits]
  test "invalid exit is detected after block withholding", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: deposit_blknum}} = Client.submit(tx)

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: tx_blknum, txhash: _tx_hash}} = Client.submit(tx)

    IntegrationTest.wait_for_block_fetch(tx_blknum, @timeout)

    {_, nonce} = get_next_blknum_nonce(tx_blknum)

    {:ok, _txhash} = Eth.RootChain.submit_block(<<0::256>>, nonce, 20_000_000_000)

    # checking if both machines and humans learn about the byzantine condition
    assert capture_log(fn ->
             IntegrationTest.wait_for_byzantine_events([%Event.BlockWithholding{}.name], @timeout)
           end) =~ inspect(:withholding)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = TestHelper.get_exit_data(deposit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => _eth_height}} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    IntegrationTest.wait_for_byzantine_events([%Event.InvalidExit{}.name], @timeout)
  end

  defp get_next_blknum_nonce(blknum) do
    child_block_interval = Application.fetch_env!(:omg_eth, :child_block_interval)
    next_blknum = blknum + child_block_interval
    {next_blknum, trunc(next_blknum / child_block_interval)}
  end
end
