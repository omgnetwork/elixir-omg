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
  alias OMG.Watcher.TestHelper

  @moduletag :integration
  @moduletag :watcher
  @moduletag timeout: 180_000

  @timeout 40_000
  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @eth_hex Encoding.to_hex(@eth)

  @tag fixtures: [:watcher, :child_chain, :stable_alice, :bob, :stable_alice_deposits]
  test "Thin client scenario", %{
    stable_alice: alice,
    bob: bob
  } do
    alice_addr = Encoding.to_hex(alice.addr)
    bob_addr = Encoding.to_hex(bob.addr)
    # 10 = 5 to Bob + 2 fee + 3 rest to Alice
    fee = 2
    alice_to_bob = 5
    alice_rest = 3

    assert %{
             "result" => "complete",
             "transactions" => [
               %{
                 "inputs" => [
                   %{
                     "blknum" => blknum,
                     "txindex" => txindex,
                     "oindex" => oindex
                   }
                 ],
                 "fee" => %{"amount" => ^fee, "currency" => @eth_hex}
                 # "sign_hash" => sign_hash,
                 # "typed_data" => typed_data
               }
             ]
           } =
             TestHelper.success?(
               "transaction.create",
               %{
                 "owner" => alice_addr,
                 "payments" => [%{"amount" => alice_to_bob, "currency" => @eth_hex, "owner" => bob_addr}],
                 "fee" => %{"amount" => fee, "currency" => @eth_hex}
               }
             )

    # =================================================================
    # TODO" => Receive following data from new - tx.create and remove this
    zero_input = %{"blknum" => 0, "txindex" => 0, "oindex" => 0}
    zero_output = %{"owner" => @eth_hex, "currency" => @eth_hex, "amount" => 0}
    zero_32_bytes = "0x0000000000000000000000000000000000000000000000000000000000000000"

    domain_spec = [
      %{"name" => "name", "type" => "string"},
      %{"name" => "version", "type" => "string"},
      %{"name" => "verifyingContract", "type" => "address"},
      %{"name" => "salt", "type" => "bytes32"}
    ]

    tx_spec = [
      %{"name" => "input0", "type" => "Input"},
      %{"name" => "input1", "type" => "Input"},
      %{"name" => "input2", "type" => "Input"},
      %{"name" => "input3", "type" => "Input"},
      %{"name" => "output0", "type" => "Output"},
      %{"name" => "output1", "type" => "Output"},
      %{"name" => "output2", "type" => "Output"},
      %{"name" => "output3", "type" => "Output"},
      %{"name" => "metadata", "type" => "bytes32"}
    ]

    input_spec = [
      %{"name" => "blknum", "type" => "uint256"},
      %{"name" => "txindex", "type" => "uint256"},
      %{"name" => "oindex", "type" => "uint256"}
    ]

    output_spec = [
      %{"name" => "owner", "type" => "address"},
      %{"name" => "currency", "type" => "address"},
      %{"name" => "amount", "type" => "uint256"}
    ]

    contract_addr = Eth.Diagnostics.get_child_chain_config()[:contract_addr]

    domain_data = %{
      "name" => "OMG Network",
      "version" => "1",
      "verifyingContract" => contract_addr,
      "salt" => "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83"
    }

    typed_data = %{
      "types" => %{
        "EIP712Domain" => domain_spec,
        "Transaction" => tx_spec,
        "Input" => input_spec,
        "Output" => output_spec
      },
      "domain" => domain_data,
      "primaryType" => "Transaction",
      "message" => %{
        "input0" => %{"blknum" => blknum, "txindex" => txindex, "oindex" => oindex},
        "input1" => zero_input,
        "input2" => zero_input,
        "input3" => zero_input,
        "output0" => %{"owner" => bob_addr, "currency" => @eth_hex, "amount" => alice_to_bob},
        "output1" => %{"owner" => alice_addr, "currency" => @eth_hex, "amount" => alice_rest},
        "output2" => zero_output,
        "output3" => zero_output,
        "metadata" => zero_32_bytes
      }
    }

    {:ok, tx} = OMG.WatcherRPC.Web.Validator.TypedDataSigned.parse_transaction(typed_data)

    sign_hash = OMG.TypedDataHash.hash_struct(tx)
    # =================================================================

    signature = DevCrypto.signature_digest(sign_hash, alice.priv)

    typed_data_signed =
      typed_data
      |> Map.put_new("signatures", [Encoding.to_hex(signature)])

    assert %{
             "blknum" => tx_blknum,
             "txindex" => tx_index
           } = TestHelper.success?("transaction.submit_typed", typed_data_signed)

    IntegrationTest.wait_for_block_fetch(tx_blknum, @timeout)

    assert [
             %{
               "blknum" => ^tx_blknum,
               "txindex" => ^tx_index,
               "amount" => ^alice_to_bob
             }
           ] = TestHelper.get_utxos(bob.addr)
  end
end
