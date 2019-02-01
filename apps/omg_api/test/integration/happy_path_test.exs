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

defmodule OMG.API.Integration.HappyPathTest do
  @moduledoc """
  Tests a simple happy path of all the pieces working together
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use Plug.Test

  alias OMG.API.Crypto
  alias OMG.API.DevCrypto
  alias OMG.API.State.Transaction
  alias OMG.Eth
  alias OMG.RPC.Web.Encoding
  alias OMG.RPC.Web.TestHelper

  @moduletag :integration

  defp eth, do: Crypto.zero_address()

  @tag fixtures: [:alice, :bob, :omg_child_chain, :token, :alice_deposits]
  test "deposit, spend, restart etc works fine", %{
    alice: alice,
    bob: bob,
    token: token,
    alice_deposits: {deposit_blknum, token_deposit_blknum}
  } do
    raw_tx = Transaction.new([{deposit_blknum, 0, 0}], [{bob.addr, eth(), 7}, {alice.addr, eth(), 3}])

    tx = raw_tx |> DevCrypto.sign([alice.priv, <<>>]) |> Transaction.Signed.encode()

    # spend the deposit
    {:ok, %{"blknum" => spend_child_block}} = submit_transaction(tx)

    token_raw_tx = Transaction.new([{token_deposit_blknum, 0, 0}], [{bob.addr, token, 8}, {alice.addr, token, 2}])

    token_tx = token_raw_tx |> DevCrypto.sign([alice.priv, <<>>]) |> Transaction.Signed.encode()

    # spend the token deposit
    assert {:ok, %{"blknum" => spend_token_child_block}} = submit_transaction(token_tx)
    {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()

    post_spend_child_block = spend_token_child_block + child_block_interval
    {:ok, _} = Eth.DevHelpers.wait_for_next_child_block(post_spend_child_block)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash, _}} = Eth.RootChain.get_child_chain(spend_child_block)
    assert {:ok, %{"transactions" => transactions}} = get_block(block_hash)

    # NOTE: we are checking only the `hd` because token_tx might possibly be in the next block
    {:ok, decoded_tx_bytes} = transactions |> hd() |> Encoding.from_hex()

    assert {:ok, %{raw_tx: ^raw_tx}} =
             decoded_tx_bytes
             |> Transaction.Signed.decode()

    # Restart everything to check persistance and revival
    [:omg_api, :omg_eth, :omg_db] |> Enum.each(&Application.stop/1)

    {:ok, started_apps} = Application.ensure_all_started(:omg_api)
    # sanity check, did-we restart really?
    assert Enum.member?(started_apps, :omg_api)

    # repeat spending to see if all works

    raw_tx2 = Transaction.new([{spend_child_block, 0, 0}, {spend_child_block, 0, 1}], [{alice.addr, eth(), 10}])
    tx2 = raw_tx2 |> DevCrypto.sign([bob.priv, alice.priv]) |> Transaction.Signed.encode()

    # spend the output of the first tx
    assert {:ok, %{"blknum" => spend_child_block2}} = submit_transaction(tx2)

    post_spend_child_block2 = spend_child_block2 + child_block_interval
    {:ok, _} = Eth.DevHelpers.wait_for_next_child_block(post_spend_child_block2)

    # check if operator is propagating block with hash submitted to RootChain
    {:ok, {block_hash2, _}} = Eth.RootChain.get_child_chain(spend_child_block2)

    assert {:ok, %{"transactions" => [transaction2]}} = get_block(block_hash2)

    {:ok, decoded_tx2_bytes} = transaction2 |> Encoding.from_hex()

    assert {:ok, %{raw_tx: ^raw_tx2}} =
             decoded_tx2_bytes
             |> Transaction.Signed.decode()

    # sanity checks, mainly persistence & failure responses
    assert {:ok, %{}} = get_block(block_hash)
    assert {:error, %{"code" => "get_block:not_found"}} = get_block(<<0::size(256)>>)

    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(tx)

    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(tx2)

    assert {:error, %{"code" => "submit:utxo_not_found"}} = submit_transaction(token_tx)
  end

  defp submit_transaction(tx) do
    TestHelper.rpc_call(:post, "/transaction.submit", %{transaction: Encoding.to_hex(tx)})
    |> get_body_data()
  end

  defp get_block(hash) do
    TestHelper.rpc_call(:post, "/block.get", %{hash: Encoding.to_hex(hash)})
    |> get_body_data()
  end

  defp get_body_data(resp_body) do
    {
      if(resp_body["success"], do: :ok, else: :error),
      resp_body["data"]
    }
  end
end
