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

defmodule OMG.RPC.Web.TestHelper do
  @moduledoc """
  Provides common testing functions used by App's tests.
  """

  import ExUnit.Assertions
  use Plug.Test

  def rpc_call(method, path, params_or_body \\ nil) do
    request =
      conn(method, path, params_or_body)
      |> put_req_header("content-type", "application/json")

    response = request |> send_request

    assert response.status == 200

    Poison.decode!(response.resp_body)
  end

  defp send_request(req) do
    req
    |> OMG.RPC.Web.Endpoint.call([])
  end
end
