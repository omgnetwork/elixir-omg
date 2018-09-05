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

defmodule OMG.Watcher.Web.TxOutputDBTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures

  alias OMG.API
  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.API.Utxo
  alias OMG.Watcher.TransactionDB
  alias OMG.Watcher.TxOutputDB

  require Utxo

  @eth Crypto.zero_address()

  describe "Utxo database" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "compose_utxo_exit should return proper proof format", %{alice: alice} do
      TransactionDB.update_with(%Block{
        transactions: [
          API.TestHelper.create_recovered([], @eth, [{alice, 120}]),
          API.TestHelper.create_recovered([], @eth, [{alice, 110}]),
          API.TestHelper.create_recovered([], @eth, [{alice, 100}])
        ],
        number: 1000
      })

      {:ok,
       %{
         utxo_pos: _utxo_pos,
         txbytes: _txbytes,
         proof: proof,
         sigs: _sigs
       }} = TxOutputDB.compose_utxo_exit(Utxo.position(1000, 1, 0))

      assert <<_proof::bytes-size(512)>> = proof
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "compose_utxo_exit should return error when there is no txs in specfic block" do
      {:error, :no_tx_for_given_blknum} = TxOutputDB.compose_utxo_exit(Utxo.position(1, 1, 0))
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "compose_utxo_exit should return error when there is no tx in specfic block", %{alice: alice} do
      TransactionDB.update_with(%Block{
        transactions: [
          API.TestHelper.create_recovered([], @eth, [{alice, 120}]),
          API.TestHelper.create_recovered([], @eth, [{alice, 110}]),
          API.TestHelper.create_recovered([], @eth, [{alice, 100}])
        ],
        number: 1000
      })

      {:error, :no_tx_for_given_blknum} = TxOutputDB.compose_utxo_exit(Utxo.position(1000, 3, 0))
    end
  end
end
