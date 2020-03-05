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

defmodule OMG.WatcherRPC.Web.Controller.EnforceContentPlugTest do
  @moduledoc """
  This test module tested header enforcing which we decided to remove in #759. Instead of removing it, it was reversed
  to show no header is required. We can remove this test as it basically shows HTTP protocol behavior.
  """
  use OMG.WatcherInfo.DataCase, async: true
  use Plug.Test
  alias OMG.Utils.HttpRPC.Encoding

  test "Content type header is no longer required" do
    no_account = Encoding.to_hex(<<0::160>>)
    post = conn(:post, "account.get_balance", %{"address" => no_account})
    response = OMG.WatcherRPC.Web.Endpoint.call(post, [])

    assert response.status == 200
    assert %{"success" => true} = Jason.decode!(response.resp_body)
  end
end
