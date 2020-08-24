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

defmodule OMG.Childchain.ReleaseTasks.SetSubmitBlockWhenNTxsTest do
  use ExUnit.Case, async: true
  alias OMG.ChildChain.ReleaseTasks.SetBlockSubmitWhenNTxs

  @app :omg_child_chain
  @env_key "BLOCK_SUBMIT_WHEN_N_TXS"
  @config_key :block_submit_when_n_txs

  test "that txs count is set when the env var is present" do
    :ok = System.put_env(@env_key, "1234")
    config = SetBlockSubmitWhenNTxs.load([], [])
    block_submit_when_n_txs = config |> Keyword.fetch!(@app) |> Keyword.fetch!(@config_key)
    assert block_submit_when_n_txs == 1234
    :ok = System.delete_env(@env_key)
  end

  test "that the default config is used when the env var is not set" do
    old_config = Application.get_env(@app, @config_key)
    :ok = System.delete_env(@env_key)
    config = SetBlockSubmitWhenNTxs.load([], [])
    block_submit_when_n_txs = config |> Keyword.fetch!(@app) |> Keyword.fetch!(@config_key)
    assert block_submit_when_n_txs == old_config
  end

  test "fails when env var value is not integer" do
    :ok = System.put_env(@env_key, "not an integer")
    assert_raise ArgumentError, fn -> SetBlockSubmitWhenNTxs.load([], []) end
    :ok = System.delete_env(@env_key)
  end
end
