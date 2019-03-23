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

defmodule OMG.Watcher.Web.Controller.EnforceContentPlugTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use Plug.Test
  alias OMG.RPC.Web.Encoding

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "Request missing expected content type header is rejected" do
    no_account = Encoding.to_hex(<<0::160>>)

    response =
      conn(:post, "account.get_balance", %{"address" => no_account})
      |> OMG.Watcher.Web.Endpoint.call([])

    assert response.status == 200

    assert %{
             "data" => %{
               "code" => "operation:invalid_content",
               "description" => "Content type of application/json header is required for all requests.",
               "object" => "error"
             },
             "success" => false,
             "version" => "1.0"
           } == Poison.decode!(response.resp_body)
  end
end
