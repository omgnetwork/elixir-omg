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

  import OMG.Watcher.ExitProcessor.TestHelper

  @recently_added_keys [:root_chain_txhash]
  @utxo_pos_1 {0, 0, 0}
  @exit_1 %{
    exit_id: 1,
    amount: 1,
    currency: random_bytes(20),
    eth_height: 1,
    exiting_txbytes: random_bytes(32),
    is_active: false,
    owner: random_bytes(20),
    root_chain_txhash: random_bytes(32)
  }

  describe "from_db_kv/1" do
    test "default recently added keys to nil for existing entries without said key" do
      exit_info = Map.drop(@exit_1, @recently_added_keys)

      {_, exit_info_struct} = ExitInfo.from_db_kv({@utxo_pos_1, exit_info})

      Enum.each(@recently_added_keys, fn recently_added_key ->
        value = Map.get(exit_info_struct, recently_added_key)
        assert value == nil
      end)
    end

    test "accepts an exit argument with root_chain_txhash and includes in the struct" do
      {_, exit_info_struct} = ExitInfo.from_db_kv({@utxo_pos_1, @exit_1})

      assert Map.get(exit_info_struct, :root_chain_txhash) == Map.get(@exit_1, :root_chain_txhash)
    end
  end
end
