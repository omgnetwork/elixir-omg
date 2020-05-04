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

defmodule OMG.Watcher.ExitProcessor.ExitInfoTest do
  @moduledoc """
  Test of the logic of the exit_info module
  """
  use OMG.Watcher.ExitProcessor.Case, async: true

  alias OMG.Watcher.ExitProcessor.ExitInfo

  @recently_added_keys [:root_chain_txhash, :scheduled_finalization_time, :timestamp]
  @utxo_pos_1 {1000, 0, 0}
  @exit_1 %{
    exit_id: 1,
    amount: 1,
    currency: <<1::160>>,
    eth_height: 1,
    exiting_txbytes: "txbytes",
    is_active: false,
    owner: <<1::160>>,
    root_chain_txhash: <<1::256>>,
    timestamp: 1,
    scheduled_finalization_time: 2
  }

  @min_exit_period 20
  @child_block_interval 1000

  describe "from_db_kv/1" do
    test "default recently added keys to nil for existing entries without said key" do
      exit_info = Map.drop(@exit_1, @recently_added_keys)

      {_, exit_info_struct} = ExitInfo.from_db_kv({@utxo_pos_1, exit_info})

      Enum.each(@recently_added_keys, fn recently_added_key ->
        value = Map.get(exit_info_struct, recently_added_key)
        assert value == nil
      end)
    end

    test "accepts an exit argument with recently added keys and includes them in the struct" do
      {_, exit_info_struct} = ExitInfo.from_db_kv({@utxo_pos_1, @exit_1})

      Enum.each(@recently_added_keys, fn recently_added_key ->
        assert Map.get(exit_info_struct, recently_added_key) == Map.get(@exit_1, recently_added_key)
      end)
    end
  end

  describe "calculate_sft/4" do
    test "calculates scheduled finalisation time correctly if UTXO was created by a deposit" do
      deposit_blknum = 2001
      utxo_creation_ts = 50
      # By setting the exit timestamp at within @min_exit_period from the creation of the UTXO,
      # the fact that the UTXO was a deposit changes the resulting scheduled finalisation time,
      # thereby testing as intended.
      exit_ts = utxo_creation_ts + @min_exit_period - 10

      expected_sft = max(exit_ts + @min_exit_period, utxo_creation_ts + @min_exit_period)

      assert {:ok, expected_sft} ==
               ExitInfo.calculate_sft(
                 deposit_blknum,
                 exit_ts,
                 utxo_creation_ts,
                 @min_exit_period,
                 @child_block_interval
               )
    end

    test "calculates scheduled finalisation time correctly if UTXO was created by a child chain transaction" do
      blknum = 2000
      utxo_creation_ts = 50
      # By setting the exit timestamp at within @min_exit_period from the creation of the UTXO,
      # the fact that the UTXO was not created by a deposit changes the resulting scheduled finalisation time,
      # thereby testing as intended.
      exit_ts = utxo_creation_ts + @min_exit_period - 10

      expected_sft = max(exit_ts + @min_exit_period, utxo_creation_ts + 2 * @min_exit_period)

      assert {:ok, expected_sft} ==
               ExitInfo.calculate_sft(
                 blknum,
                 exit_ts,
                 utxo_creation_ts,
                 @min_exit_period,
                 @child_block_interval
               )
    end
  end
end
