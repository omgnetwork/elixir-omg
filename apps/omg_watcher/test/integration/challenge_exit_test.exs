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

defmodule OMG.Watcher.Integration.ChallengeExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use OMG.API.Integration.Fixtures

  use Plug.Test

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.Eth
  alias OMG.JSONRPC.Client
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias OMG.Watcher.TestHelper, as: Test

  @moduletag :integration

  @timeout 20_000
  @zero_address Crypto.zero_address()
  @eth @zero_address

  @tag fixtures: [:watcher_sandbox, :child_chain, :alice, :alice_deposits]
  test "exit eth, with challenging an invalid exit", %{alice: alice, alice_deposits: {deposit_blknum, _}} do
    # NOTE: we're explicitly skipping erc20 challenges here, because eth and erc20 exits/challenges work the exact same
    #       way, so the integration is tested with the eth test

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: exiting_utxo_block_nr}} = Client.call(:submit, %{transaction: tx})

    IntegrationTest.wait_until_block_getter_fetches_block(exiting_utxo_block_nr, @timeout)

    tx2 = API.TestHelper.create_encoded([{exiting_utxo_block_nr, 0, 0, alice}], @eth, [{alice, 10}])
    {:ok, %{blknum: double_spend_block_nr}} = Client.call(:submit, %{transaction: tx2})

    IntegrationTest.wait_until_block_getter_fetches_block(double_spend_block_nr, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "sigs" => sigs,
      "utxo_pos" => utxo_pos
    } = IntegrationTest.compose_utxo_exit(exiting_utxo_block_nr, 0, 0)

    {:ok, alice_address} = Crypto.encode_address(alice.addr)

    {:ok, txhash} =
      Eth.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        1,
        alice_address
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    # after a successful invalid exit starting, the Watcher should be able to assist in successful challenging
    challenge = get_exit_challenge(exiting_utxo_block_nr, 0, 0)
    assert {:ok, {alice.addr, @eth, 10}} == Eth.get_exit(utxo_pos)

    {:ok, txhash} =
      OMG.Eth.DevHelpers.challenge_exit(
        challenge["cutxopos"],
        challenge["eutxoindex"],
        challenge["txbytes"],
        challenge["proof"],
        challenge["sigs"],
        alice_address
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash, @timeout)
    assert {:ok, {@zero_address, @eth, 10}} == Eth.get_exit(utxo_pos)
  end

  defp get_exit_challenge(blknum, txindex, oindex) do
    assert %{"result" => "success", "data" => decoded_data} =
             Test.rest_call(:get, "challenges?blknum=#{blknum}&txindex=#{txindex}&oindex=#{oindex}")

    Crypto.decode16(decoded_data, ["txbytes", "proof", "sigs"])
  end
end
