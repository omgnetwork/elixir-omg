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

defmodule OMG.Watcher.Web.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.Watcher.DB.TransactionDB
  alias OMG.Watcher.TestHelper

  @eth Crypto.zero_address()

  describe "Controller.TransactionTest" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "transaction/:id endpoint returns expected transaction format", %{alice: alice} do
      [
        ok: %TransactionDB{
          blknum: blknum,
          txindex: txindex,
          txhash: txhash
        }
      ] =
        TransactionDB.update_with(%{
          transactions: [
            API.TestHelper.create_recovered([{1, 1, 0, alice}], @eth, [{alice, 120}])
          ],
          blknum: 1,
          eth_height: 1
        })

      alice_addr = alice.addr |> TestHelper.to_response_address()
      txhash = Base.encode16(txhash)
      zero_addr = String.duplicate("0", 2 * 20)
      zero_sign = String.duplicate("0", 2 * 65)

      assert %{
               "data" => %{
                 "txid" => ^txhash,
                 "txblknum" => ^blknum,
                 "txindex" => ^txindex,
                 "blknum1" => 1,
                 "txindex1" => 1,
                 "oindex1" => 0,
                 "blknum2" => 0,
                 "txindex2" => 0,
                 "oindex2" => 0,
                 "cur12" => ^zero_addr,
                 "newowner1" => ^alice_addr,
                 "amount1" => 120,
                 "newowner2" => ^zero_addr,
                 "amount2" => 0,
                 "sig1" => <<_sig1::binary-size(130)>>,
                 "sig2" => ^zero_sign,
                 "spender1" => ^alice_addr,
                 "spender2" => nil
               },
               "result" => "success"
             } = TestHelper.rest_call(:get, "/transaction/#{txhash}")
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "transaction/:id endpoint returns error for non exsiting transaction" do
      txhash = "055673FF58D85BFBF6844BAD62361967C7D19B6A4768CE4B54C687B65728D721"

      assert %{
               "data" => %{
                 "code" => "transaction:not_found",
                 "description" => "Transaction doesn't exist for provided search criteria"
               },
               "result" => "error"
             } == TestHelper.rest_call(:get, "/transaction/#{txhash}", nil, 404)
    end
  end
end
