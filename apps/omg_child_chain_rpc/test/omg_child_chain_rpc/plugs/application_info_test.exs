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

defmodule OMG.ChildChainRPC.Plugs.ApplicationInfoTest do
  @moduledoc false
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  alias OMG.Utils.HttpRPC.Plugs.ApplicationInfo

  describe "call/2" do
    test "service name is appended" do
      conn = build_conn() |> ApplicationInfo.call(application: :omg_child_chain_rpc)
      assert "child_chain" == conn.assigns.app_infos.service_name
    end

    test "version is appended and follows semver" do
      conn = build_conn() |> ApplicationInfo.call(application: :omg_child_chain_rpc)
      assert {:ok, _} = Version.parse(conn.assigns.app_infos.version)
    end
  end
end
