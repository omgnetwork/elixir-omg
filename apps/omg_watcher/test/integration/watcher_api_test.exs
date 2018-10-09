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

defmodule OMG.Watcher.Integration.WatcherApiTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use OMG.API.Integration.Fixtures
  use Plug.Test

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.API.Utxo
  alias OMG.Eth
  alias OMG.JSONRPC.Client
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest

  require Utxo

  @timeout 40_000
  @eth Crypto.zero_address()
  @eth_hex String.duplicate("00", 20)

  @moduletag :integration

  @tag fixtures: [:watcher_sandbox, :child_chain, :token, :alice, :bob, :alice_deposits]
  test "utxos from deposits on child chain are available in WatcherDB until exited", %{
    alice: alice,
    bob: bob,
    token: token,
    alice_deposits: {deposit_blknum, token_deposit_blknum}
  } do
    token_addr = token |> Base.encode16()

    # expected utxos
    eth_deposit = %{
      "amount" => 10,
      "blknum" => deposit_blknum,
      "txindex" => 0,
      "oindex" => 0,
      "currency" => @eth_hex,
      "txbytes" => nil
    }

    token_deposit = %{
      "amount" => 10,
      "blknum" => token_deposit_blknum,
      "txindex" => 0,
      "oindex" => 0,
      "currency" => token_addr,
      "txbytes" => nil
    }

    # utxo from deposit should be available
    assert [eth_deposit, token_deposit] == IntegrationTest.get_utxos(alice)

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    {:ok, %{blknum: block_nr}} = Client.call(:submit, %{transaction: tx})

    IntegrationTest.wait_until_block_getter_fetches_block(block_nr, @timeout)

    encode_tx = Client.encode(tx)

    assert [
             %{
               "amount" => 3,
               "blknum" => ^block_nr,
               "txindex" => 0,
               "oindex" => 1,
               "currency" => @eth_hex,
               "txbytes" => ^encode_tx
             }
           ] = IntegrationTest.get_utxos(bob)

    assert [
             ^token_deposit,
             %{
               "amount" => 7,
               "blknum" => ^block_nr,
               "txindex" => 0,
               "oindex" => 0,
               "currency" => @eth_hex,
               "txbytes" => ^encode_tx
             }
           ] = IntegrationTest.get_utxos(alice)

    %{
      "utxo_pos" => utxo_pos,
      "txbytes" => txbytes,
      "proof" => proof,
      "sigs" => sigs
    } = IntegrationTest.get_exit_data(block_nr, 0, 0)

    {:ok, txhash1} =
      Eth.RootChain.start_exit(
        utxo_pos,
        txbytes,
        proof,
        sigs,
        alice.addr
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash1, @timeout)

    # exiting spends UTXO on child chain
    # wait until the exit is recognized and attempt to spend the exited utxo
    Process.sleep(4_000)

    assert [token_deposit] == IntegrationTest.get_utxos(alice)

    # finally alice exits her token deposit
    deposit_pos = Utxo.position(token_deposit_blknum, 0, 0) |> Utxo.Position.encode()

    {:ok, txhash2} =
      Eth.RootChain.start_deposit_exit(
        deposit_pos,
        token,
        10,
        alice.addr
      )

    {:ok, %{"status" => "0x1"}} = Eth.WaitFor.eth_receipt(txhash2, @timeout)

    # exiting spends UTXO on child chain
    # wait until the exit is recognized and attempt to spend the exited utxo
    Process.sleep(4_000)

    assert [] == IntegrationTest.get_utxos(alice)
  end
end
