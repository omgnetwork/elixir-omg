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

defmodule OMG.Watcher.Web.Controller.AccountTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  alias OMG.Crypto
  alias OMG.TestHelper
  alias OMG.Watcher.TestHelper

  @eth_hex <<0::160>> |> OMG.RPC.Web.Encoding.to_hex()
  @other_token <<127::160>>
  @other_token_hex @other_token |> OMG.RPC.Web.Encoding.to_hex()

  @tag fixtures: [:alice, :bob, :blocks_inserter, :initial_blocks]
  test "Account balance groups account tokens and provide sum of available funds", %{
    blocks_inserter: blocks_inserter,
    alice: alice,
    bob: bob
  } do
    assert [%{"currency" => @eth_hex, "amount" => 349}] == TestHelper.success?("account.get_balance", body_for(bob))

    # adds other token funds for alice to make more interesting
    blocks_inserter.([
      {11_000,
       [
         OMG.TestHelper.create_recovered([], @other_token, [{alice, 121}, {alice, 256}])
       ]}
    ])

    data = TestHelper.success?("account.get_balance", body_for(alice))

    assert [
             %{"currency" => @eth_hex, "amount" => 201},
             %{"currency" => @other_token_hex, "amount" => 377}
           ] == data |> Enum.sort(&(Map.get(&1, "currency") <= Map.get(&2, "currency")))
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "Account balance for non-existing account responds with empty array" do
    no_account = %{addr: <<0::160>>}

    assert [] == TestHelper.success?("account.get_balance", body_for(no_account))
  end

  defp body_for(%{addr: address}) do
    {:ok, address_encode} = Crypto.encode_address(address)
    %{"address" => address_encode}
  end

  @tag fixtures: [:initial_blocks, :alice]
  test "returns last transactions that involve given address", %{
    alice: alice
  } do
    # refer to `/transaction.all` tests for more thorough cases, this is the same
    {:ok, address} = Crypto.encode_address(alice.addr)

    assert [_] = TestHelper.success?("account.get_transactions", %{"address" => address, "limit" => 1})
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "account.get_balance handles improper type of parameter" do
    assert %{
             "object" => "error",
             "code" => "operation:bad_request",
             "description" => "Parameters required by this operation are missing or incorrect.",
             "messages" => %{
               "validation_error" => %{
                 "parameter" => "address",
                 "validator" => ":hex"
               }
             }
           } == TestHelper.no_success?("account.get_balance", %{"address" => 1_234_567_890})
  end
end
