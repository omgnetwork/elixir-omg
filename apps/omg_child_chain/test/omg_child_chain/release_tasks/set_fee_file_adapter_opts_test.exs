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
  use ExUnit.Case, async: false
  alias OMG.ChildChain.Fees.FileAdapter
  alias OMG.ChildChain.ReleaseTasks.SetFeeFileAdapterOpts

  @app :omg_child_chain
  @config_key :fee_adapter
  @env_fee_adapter "FEE_ADAPTER"
  @env_fee_specs_file_path "FEE_SPECS_FILE_PATH"

  setup do
    original_config = Application.get_all_env(@app)

    on_exit(fn ->
      # configuration is global state so we reset it to known values in case it got fiddled before
      :ok = Enum.each(original_config, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)
    end)

    {:ok, %{original_config: original_config}}
  end

  test "sets the fee adapter to FileAdapter and the given path" do
    :ok = System.put_env(@env_fee_adapter, "file")
    :ok = System.put_env(@env_fee_specs_file_path, "/tmp/YOLO/fee_file.json")
    :ok = SetFeeFileAdapterOpts.init([])

    {adapter, opts: adapter_opts} = Application.get_env(@app, @config_key)
    assert adapter == FileAdapter
    assert adapter_opts[:specs_file_path] == "/tmp/YOLO/fee_file.json"

    :ok = System.delete_env(@env_fee_adapter)
    :ok = System.delete_env(@env_fee_specs_file_path)
  end

  test "does not change the configuration when FEE_ADAPTER is not \"file\"" do
    original_config = Application.get_env(@app, @config_key)
    :ok = System.put_env(@env_fee_adapter, "not_file_adapter")
    :ok = System.put_env(@env_fee_specs_file_path, "/tmp/YOLO/fee_file.json")
    :ok = SetFeeFileAdapterOpts.init([])

    assert Application.get_env(@app, @config_key) == original_config

    :ok = System.delete_env(@env_fee_adapter)
    :ok = System.delete_env(@env_fee_specs_file_path)
  end

  test "no other configurations got affected", context do
    :ok = System.put_env(@env_fee_adapter, "file")
    :ok = System.put_env(@env_fee_specs_file_path, "/tmp/YOLO/fee_file.json")
    :ok = SetFeeFileAdapterOpts.init([])

    new_configs = @app |> Application.get_all_env() |> Keyword.delete(@config_key) |> Enum.sort()
    old_configs = context.original_config |> Keyword.delete(@config_key) |> Enum.sort()

    assert new_configs == old_configs

    :ok = System.delete_env(@env_fee_adapter)
    :ok = System.delete_env(@env_fee_specs_file_path)
  end
end
