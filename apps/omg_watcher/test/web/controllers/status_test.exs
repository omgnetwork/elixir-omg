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

  alias OMG.Watcher.TestHelper

  @moduletag :integration

  describe "Controller.StatusTest" do
    @tag fixtures: [:watcher_sandbox, :root_chain_contract_config]
    test "status endpoint returns expected response format" do
      assert %{
               "result" => "success",
               "data" => %{
                 "last_validated_child_block_number" => last_validated_child_block_number,
                 "last_mined_child_block_number" => last_mined_child_block_number,
                 "last_mined_child_block_timestamp" => last_mined_child_block_timestamp,
                 "eth_syncing" => eth_syncing
               }
             } = TestHelper.rest_call(:get, "/status")

      assert is_integer(last_validated_child_block_number)
      assert is_integer(last_mined_child_block_number)
      assert is_integer(last_mined_child_block_timestamp)
      assert is_atom(eth_syncing)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "status endpoint returns error when ethereum node is missing" do
      # we're not running geth, but need to pretend that the root chain contract is configured somehow though:
      Application.put_env(:omg_eth, :contract_addr, "0x00", persistent: true)

      {:ok, started_apps} = Application.ensure_all_started(:omg_eth)

      assert %{
               "result" => "error",
               "data" => %{"code" => "internal_server_error", "description" => "econnrefused"}
             } = TestHelper.rest_call(:get, "/status", nil, 500)

      started_apps |> Enum.each(fn app -> :ok = Application.stop(app) end)
    end
  end
end
