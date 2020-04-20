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

defmodule OMG.ChildChain.ReleaseTasks.SetFeeFileAdapterOptsTest do
  use ExUnit.Case, async: true
  alias OMG.ChildChain.Fees.FileAdapter
  alias OMG.ChildChain.ReleaseTasks.SetFeeFileAdapterOpts

  @app :omg_child_chain
  @config_key :fee_adapter
  @env_fee_adapter "FEE_ADAPTER"
  @env_fee_specs_file_path "FEE_SPECS_FILE_PATH"

  setup do
    original_config = Application.get_all_env(@app)

    on_exit(fn ->
      # Delete all related env vars
      :ok = System.delete_env(@env_fee_adapter)
      :ok = System.delete_env(@env_fee_specs_file_path)

      # configuration is global state so we reset it to known values in case it got fiddled before
      :ok = Enum.each(original_config, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)
    end)

    :ok
  end

  test "sets the fee adapter to FileAdapter and the given path" do
    :ok = System.put_env(@env_fee_adapter, "file")
    :ok = System.put_env(@env_fee_specs_file_path, "/tmp/YOLO/fee_file.json")
    config = SetFeeFileAdapterOpts.load([], [])

    {adapter, opts: adapter_opts} = config[@app][@config_key]
    assert adapter == FileAdapter
    assert adapter_opts[:specs_file_path] == "/tmp/YOLO/fee_file.json"
  end

  test "does not change the configuration when FEE_ADAPTER is not \"file\"" do
    :ok = System.put_env(@env_fee_adapter, "not_file_adapter")
    :ok = System.put_env(@env_fee_specs_file_path, "/tmp/YOLO/fee_file.json")

    assert SetFeeFileAdapterOpts.load([], []) == []
  end

  test "no other configurations got affected" do
    :ok = System.put_env(@env_fee_adapter, "file")
    :ok = System.put_env(@env_fee_specs_file_path, "/tmp/YOLO/fee_file.json")
    config = SetFeeFileAdapterOpts.load([], [])

    assert Keyword.delete(config[@app], @config_key) == []
  end
end
