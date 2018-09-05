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
  alias OMG.Watcher.TestHelper
  alias OMG.Watcher.TransactionDB

  @moduletag :integration

  @eth Crypto.zero_address()

  describe "Controller.TransactionTest" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "transaction/:id endpoint returns expected transaction format", %{alice: alice} do
      [
        ok: %TransactionDB{
          amount1: amount1,
          amount2: amount2,
          blknum1: blknum1,
          blknum2: blknum2,
          cur12: cur12,
          newowner1: newowner1,
          newowner2: newowner2,
          oindex1: oindex1,
          oindex2: oindex2,
          sig1: sig1,
          sig2: sig2,
          spender1: spender1,
          txblknum: txblknum,
          txid: txid,
          txindex: txindex,
          txindex1: txindex1,
          txindex2: txindex2
        }
      ] =
        TransactionDB.update_with(%{
          transactions: [
            API.TestHelper.create_recovered([{1, 1, 0, alice}], @eth, [{alice, 120}])
          ],
          number: 1
        })

      newowner1 = Base.encode16(newowner1)
      newowner2 = Base.encode16(newowner2)
      txid = Base.encode16(txid)
      cur12 = Base.encode16(cur12)
      sig1 = Base.encode16(sig1)
      sig2 = Base.encode16(sig2)
      spender1 = Base.encode16(spender1)

      assert %{
               "data" => %{
                 "amount1" => amount1,
                 "amount2" => amount2,
                 "blknum1" => blknum1,
                 "blknum2" => blknum2,
                 "cur12" => cur12,
                 "newowner1" => newowner1,
                 "newowner2" => newowner2,
                 "oindex1" => oindex1,
                 "oindex2" => oindex2,
                 "sig1" => sig1,
                 "sig2" => sig2,
                 "spender1" => spender1,
                 "spender2" => nil,
                 "txblknum" => txblknum,
                 "txid" => txid,
                 "txindex" => txindex,
                 "txindex1" => txindex1,
                 "txindex2" => txindex2
               },
               "result" => "success"
             } == TestHelper.rest_call(:get, "/transaction/#{txid}")
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "transaction/:id endpoint returns error for non exsiting transaction" do
      txid = "055673FF58D85BFBF6844BAD62361967C7D19B6A4768CE4B54C687B65728D721"

      assert %{
               "data" => %{
                 "code" => "transaction:not_found",
                 "description" => "Transaction doesn't exist for provided search criteria"
               },
               "result" => "error"
             } == TestHelper.rest_call(:get, "/transaction/#{txid}")
    end
  end
end
