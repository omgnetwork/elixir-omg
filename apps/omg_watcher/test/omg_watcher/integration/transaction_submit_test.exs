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

defmodule OMG.Watcher.Integration.TransactionSubmitTest do
  @moduledoc """
  Tests thin-client scenario:
  Assuming funded address

  1. call `/transaction.create` to prepare transaction with data ready to be signed with `eth_signTypedData`
  2. call Ethereum node (e.g. MetaMask) with above data as request to sign transaction
  3. call `/transaction.submit_typed` with typed data and signatures to submit transaction  to child chain


  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use Plug.Test

  alias OMG.DevCrypto
  alias OMG.Eth
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.WatcherHelper

  @moduletag :integration
  @moduletag :watcher
  @moduletag timeout: 180_000

  @timeout 40_000
  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @eth_hex Encoding.to_hex(@eth)

  @tag fixtures: [:in_beam_watcher, :mix_based_child_chain, :stable_alice, :bob, :stable_alice_deposits]
  test "Thin client scenario", %{
    stable_alice: alice,
    bob: bob
  } do
    alice_addr = Encoding.to_hex(alice.addr)
    bob_addr = Encoding.to_hex(bob.addr)
    # 10 = 5 to Bob + 0 fee + 5 rest to Alice
    alice_to_bob = 5

    order = %{
      "owner" => alice_addr,
      "payments" => [%{"amount" => alice_to_bob, "currency" => @eth_hex, "owner" => bob_addr}],
      "fee" => %{"currency" => @eth_hex}
    }

    %{
      "result" => "complete",
      "transactions" => [
        %{
          "sign_hash" => sign_hash,
          "typed_data" => typed_data
        }
      ]
    } = WatcherHelper.success?("transaction.create", order)

    signature =
      sign_hash
      |> Eth.Encoding.from_hex()
      |> DevCrypto.signature_digest(alice.priv)

    typed_data_signed =
      typed_data
      |> Map.put_new("signatures", [Encoding.to_hex(signature)])

    assert %{
             "blknum" => tx_blknum,
             "txindex" => tx_index
           } = WatcherHelper.success?("transaction.submit_typed", typed_data_signed)

    IntegrationTest.wait_for_block_fetch(tx_blknum, @timeout)

    assert [
             %{
               "blknum" => ^tx_blknum,
               "txindex" => ^tx_index,
               "amount" => ^alice_to_bob
             }
           ] = WatcherHelper.get_utxos(bob.addr)
  end
end
