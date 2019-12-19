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

defmodule OMG.WatcherInfo.DB.RepoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  import OMG.WatcherInfo.Factory

  alias OMG.WatcherInfo.DB

  alias OMG.Utxo
  require OMG.Utxo

  describe "DB.Repo.insert_all_chunked/3" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "insert_all_chunked adds inserted_at and updated_at timestamps correctly" do
      txoutput = params_for(:txoutput)

      DB.Repo.insert_all_chunked(OMG.WatcherInfo.DB.TxOutput, [txoutput])

      txoutput_with_dates =
        DB.TxOutput.get_by_position(Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex))

      assert not is_nil(txoutput_with_dates.inserted_at)
      assert not is_nil(txoutput_with_dates.updated_at)
      assert DateTime.compare(txoutput_with_dates.inserted_at, txoutput_with_dates.updated_at) == :eq
    end
  end

  describe "OMG.WatcherInfo.DB.TxOutput.spend_utxos/3" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "spend_utxos updates the updated_at timestamp correctly" do
      txoutput = params_for(:txoutput)

      DB.Repo.insert_all_chunked(DB.TxOutput, [txoutput])

      txoutput_with_dates =
        DB.TxOutput.get_by_position(Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex))

      utxo_inputs = [
        {
          Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex),
          nil,
          nil
        }
      ]

      DB.TxOutput.spend_utxos(utxo_inputs)

      txoutput_with_updated_updated_at_date =
        DB.TxOutput.get_by_position(Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex))

      assert not is_nil(txoutput_with_updated_updated_at_date.inserted_at)
      assert not is_nil(txoutput_with_updated_updated_at_date.updated_at)
      assert DateTime.compare(txoutput_with_dates.inserted_at, txoutput_with_updated_updated_at_date.inserted_at) == :eq

      assert DateTime.compare(
               txoutput_with_updated_updated_at_date.inserted_at,
               txoutput_with_updated_updated_at_date.updated_at
             ) == :lt
    end
  end
end
