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

defmodule OMG.WatcherRPC.Web.Controller.AlarmTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  use OMG.Fixtures
  use OMG.WatcherInfo.Fixtures
  use Phoenix.ConnTest

  @endpoint OMG.WatcherRPC.Web.Endpoint
  setup do
    {:ok, apps} = Application.ensure_all_started(:omg_status)

    Enum.each(
      :gen_event.call(:alarm_handler, OMG.Status.Alert.AlarmHandler, :get_alarms),
      fn alarm -> :alarm_handler.clear_alarm(alarm) end
    )

    on_exit(fn ->
      Enum.each(Enum.reverse(apps), fn app -> :ok = Application.stop(app) end)
    end)
  end

  ### a very basic test of empty alarms should be sufficient, alarms encoding is
  ### covered in OMG.Utils.HttpRPC.ResponseTest
  @tag fixtures: [:phoenix_ecto_sandbox, :db_initialized]
  test "if the controller returns the correct result when there's no alarms raised", _ do
    assert [] == get("alarm.get")
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :db_initialized]
  test "sets remote ip from X-Forwarded-For header", _ do
    response =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-forwarded-for", "99.99.99.99")
      |> get("alarm.get")

    assert response.remote_ip == {99, 99, 99, 99}
  end

  defp get(path) do
    response_body = rpc_call_get(path, 200)
    version = Map.get(response_body, "version")

    %{"version" => ^version, "success" => true, "data" => data} = response_body
    data
  end

  defp rpc_call_get(path, expected_resp_status) do
    response = get(put_req_header(build_conn(), "content-type", "application/json"), path)
    # CORS check
    assert ["*"] == get_resp_header(response, "access-control-allow-origin")

    required_headers = [
      "access-control-allow-origin",
      "access-control-expose-headers",
      "access-control-allow-credentials"
    ]

    for header <- required_headers do
      assert header in Keyword.keys(response.resp_headers)
    end

    # CORS check
    assert response.status == expected_resp_status
    Jason.decode!(response.resp_body)
  end
end
