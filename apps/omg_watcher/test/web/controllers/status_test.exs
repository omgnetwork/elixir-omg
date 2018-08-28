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

defmodule OMG.Watcher.Web.Controller.StatusTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.Watcher.TestHelper, as: Test

  @moduletag :integration

  @tag fixtures: [:watcher_sandbox, :root_chain_contract_config]
  test "status endpoint provides expected information" do
    expected_data_keys = [
      "eth_syncing",
      "last_mined_child_block_number",
      "last_mined_child_block_timestamp",
      "last_validated_child_block_number"
    ]

    %{"result" => "success", "data" => data} = Test.rest_call(:get, "/status")

    assert expected_data_keys == Map.keys(data)

    assert is_integer(Map.fetch!(data, "last_validated_child_block_number"))
    assert is_integer(Map.fetch!(data, "last_mined_child_block_number"))
    assert is_integer(Map.fetch!(data, "last_mined_child_block_timestamp"))
    assert is_atom(Map.fetch!(data, "eth_syncing"))
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "status fails gracefully when ethereum node is missing" do
    {:ok, started_apps} = Application.ensure_all_started(:omg_eth)
    assert %{"result" => "error", "data" => %{"code" => "internal_server_error", "description" => "econnrefused"}} = Test.rest_call(:get, "/status")
    started_apps |> Enum.each(fn app -> :ok = Application.stop(app) end)
  end
end
