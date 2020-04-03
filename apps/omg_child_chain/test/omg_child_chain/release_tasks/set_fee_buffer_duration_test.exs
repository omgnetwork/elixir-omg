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

defmodule OMG.ChildChain.ReleaseTasks.SetFeeBufferDurationTest do
  use ExUnit.Case, async: true
  alias OMG.ChildChain.ReleaseTasks.SetFeeBufferDuration

  @app :omg_child_chain
  @config_key :fee_buffer_duration_ms
  @env_var_name "FEE_BUFFER_DURATION_MS"

  test "duration is set when the env var is present" do
    :ok = System.put_env(@env_var_name, "30000")
    config = SetFeeBufferDuration.load([], [])
    fee_buffer_duration_ms = config |> Keyword.fetch!(@app) |> Keyword.fetch!(@config_key)
    assert fee_buffer_duration_ms == 30_000
    :ok = System.delete_env(@env_var_name)
  end

  test "takes the default app env value if not defined in sys ENV" do
    :ok = System.delete_env(@env_var_name)
    fee_buffer_duration_ms = Application.get_env(@app, @config_key)
    config = SetFeeBufferDuration.load([], [])
    config_fee_buffer_duration_ms = config |> Keyword.fetch!(@app) |> Keyword.fetch!(@config_key)
    assert fee_buffer_duration_ms == config_fee_buffer_duration_ms
  end

  test "fails if FEE_BUFFER_DURATION_MS is not a valid stringified integer" do
    :ok = System.put_env(@env_var_name, "invalid")
    assert catch_error(SetFeeBufferDuration.load([], [])) == :badarg
    :ok = System.delete_env(@env_var_name)
  end
end
