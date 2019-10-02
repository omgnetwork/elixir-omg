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

defmodule OMG.Watcher.Integration.InvalidExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use Plug.Test

  alias OMG.Utxo
  require Utxo
  alias OMG.Eth
  alias OMG.Watcher
  alias OMG.Watcher.{Event, TestHelper}
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest

  import ExUnit.CaptureLog

  @moduletag :integration
  @moduletag :watcher
  @moduletag timeout: 120_000

  @timeout 40_000
  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:watcher, :stable_alice, :child_chain, :token, :stable_alice_deposits]
  test "exit which is using already spent utxo from transaction and deposit causes to emit invalid_exit event", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    %{"txbytes" => deposit_txbytes, "proof" => deposit_proof, "utxo_pos" => deposit_utxo_pos} =
      TestHelper.get_exit_data(deposit_blknum, 0, 0)

    %{"blknum" => first_tx_blknum} =
      OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}]) |> TestHelper.submit()

    %{"blknum" => second_tx_blknum} =
      OMG.TestHelper.create_encoded([{first_tx_blknum, 0, 0, alice}], @eth, [{alice, 10}]) |> TestHelper.submit()

    IntegrationTest.wait_for_block_fetch(second_tx_blknum, @timeout)

    %{"txbytes" => txbytes, "proof" => proof, "utxo_pos" => tx_utxo_pos} =
      TestHelper.get_exit_data(first_tx_blknum, 0, 0)

    {:ok, %{"status" => "0x1"}} =
      Eth.RootChainHelper.start_exit(tx_utxo_pos, txbytes, proof, alice.addr)
      |> Eth.DevHelpers.transact_sync!()

    {:ok, %{"status" => "0x1"}} =
      Eth.RootChainHelper.start_exit(deposit_utxo_pos, deposit_txbytes, deposit_proof, alice.addr)
      |> Eth.DevHelpers.transact_sync!()

    IntegrationTest.wait_for_byzantine_events([%Event.InvalidExit{}.name, %Event.InvalidExit{}.name], @timeout)

    # after the notification has been received, a challenged is composed and sent
    _challenge = TestHelper.get_exit_challenge(first_tx_blknum, 0, 0)

    # TODO: git blame here to bring back removed failing test code, when challenges are re-integrated with the contract
  end

  @tag fixtures: [:watcher, :stable_alice, :child_chain, :token, :stable_alice_deposits, :test_server]
  test "transaction which is using already spent utxo from exit and happened before end of margin of slow validator (m_sv) causes to emit invalid_exit event",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}, test_server: context} do
    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    %{"blknum" => exit_blknum} = TestHelper.submit(tx)

    # Here we're preparing invalid block
    bad_block_number = 2_000
    bad_tx = OMG.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], @eth, [{alice, 10}])

    %{hash: bad_block_hash, number: _, transactions: _} =
      bad_block = OMG.Block.hashed_txs_at([bad_tx], bad_block_number)

    # from now on the child chain server is broken until end of test
    Watcher.Integration.BadChildChainServer.prepare_route_to_inject_bad_block(context, bad_block)

    IntegrationTest.wait_for_block_fetch(exit_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = TestHelper.get_exit_data(exit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => _eth_height}} =
      Eth.RootChainHelper.start_exit(
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

  @tag fixtures: [:watcher, :stable_alice, :child_chain, :token, :stable_alice_deposits]
  test "invalid exit is detected after block withholding", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    %{"blknum" => deposit_blknum} = TestHelper.submit(tx)

    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    %{"blknum" => tx_blknum, "txhash" => _tx_hash} = TestHelper.submit(tx)

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
      Eth.RootChainHelper.start_exit(
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
