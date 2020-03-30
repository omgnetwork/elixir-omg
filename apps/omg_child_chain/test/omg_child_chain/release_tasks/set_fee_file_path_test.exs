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

defmodule OMG.ChildChain.ReleaseTasks.SetFeeFilePathTest do
  use ExUnit.Case, async: false
  alias OMG.ChildChain.ReleaseTasks.SetFeeFilePath

  @app :omg_child_chain
  @config_key :fee_specs_file_path
  @env_var_name "FEE_SPECS_FILE_PATH"

  setup do
    original_config = Application.get_all_env(@app)

    on_exit(fn ->
      # configuration is global state so we reset it to known values in case it got fiddled before
      :ok = Enum.each(original_config, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)
    end)

    {:ok, %{original_config: original_config}}
  end

  test "path is set when the env var is present" do
    :ok = System.put_env(@env_var_name, "/tmp/YOLO/fee_file.json")
    :ok = SetFeeFilePath.init([])
    assert Application.get_env(@app, @config_key) == "/tmp/YOLO/fee_file.json"
    :ok = System.delete_env(@env_var_name)
  end

  test "takes the default app env value if not defined in sys ENV" do
    :ok = System.delete_env(@env_var_name)
    current_value = Application.get_env(@app, @config_key)
    :ok = SetFeeFilePath.init([])
    assert current_value == Application.get_env(@app, @config_key)
  end

  test "creates an empty json file at the destination" do
    file_path = "/tmp/YOLO/fee_file.json"
    :ok = System.put_env(@env_var_name, file_path)

    :ok = SetFeeFilePath.init([])
    assert File.read(file_path) == {:ok, "{}"}

    :ok = System.delete_env(@env_var_name)
  end

  test "no other configurations got affected", context do
    :ok = System.put_env(@env_var_name, "/tmp/YOLO/fee_file.json")
    :ok = SetFeeFilePath.init([])
    new_configs = @app |> Application.get_all_env() |> Keyword.delete(@config_key) |> Enum.sort()
    old_configs = context.original_config |> Keyword.delete(@config_key) |> Enum.sort()

    assert new_configs == old_configs
  end
end
