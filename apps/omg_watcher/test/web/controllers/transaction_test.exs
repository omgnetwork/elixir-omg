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
  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.Watcher.TestHelper
  alias OMG.Watcher.TransactionDB

  @eth Crypto.zero_address()

  describe "Controller.TransactionTest" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "transaction/:id endpoint returns expected transaction format", %{alice: alice} do
      # FIXME: fix return struct from this endpoint and swagger doc
      [
        ok: %TransactionDB{
          txhash: txhash,
          blknum: blknum,
          txindex: txindex
        }
      ] =
        TransactionDB.update_with(%{
          transactions: [
            API.TestHelper.create_recovered([{1, 1, 0, alice}], @eth, [{alice, 120}])
          ],
          number: 1
        })

      txhash = Base.encode16(txhash)

      assert %{
               "data" => %{
                 "txhash" =>
                 "blknum" => blknum,
                 "txindex" => txindex
               },
               "result" => "success"
             } == TestHelper.rest_call(:get, "/transaction/#{txid}")
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "transaction/:id endpoint returns expected transaction format", %{alice: alice} do
      [
        ok: %TransactionDB{
          blknum: blknum,
          txindex: txindex,
          txhash: txhash,

        }
      ] =
        TransactionDB.update_with(%Block{
          transactions: [
            API.TestHelper.create_recovered([{1, 1, 0, alice}], @eth, [{alice, 120}])
          ],
          number: 1
        })

      txhash = Base.encode16(txhash)

      assert %{
               "data" => %{
                 "blknum" => ^blknum,
                 "eth_height" => _eth_height,
                 "sent_at" => _send_at,
                 "txbytes" => _txbytes,
                 "txhash" => ^txhash,
                 "txindex" => ^txindex
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
