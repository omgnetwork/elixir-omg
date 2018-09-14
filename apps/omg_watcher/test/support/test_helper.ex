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

defmodule OMG.Watcher.TestHelper do
  @moduledoc """
  Module provides common testing functions used by App's tests.
  """

  import ExUnit.Assertions
  use Plug.Test

  def wait_for_process(pid, timeout \\ :infinity) when is_pid(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _, _} ->
        :ok
    after
      timeout ->
        throw({:timeouted_waiting_for, pid})
    end
  end

  def rest_call(method, path, params_or_body \\ nil, expected_resp_status \\ 200) do
    request = conn(method, path, params_or_body)
    response = request |> send_request
    assert response.status == expected_resp_status
    Poison.decode!(response.resp_body)
  end

  defp send_request(req) do
    req
    |> put_private(:plug_skip_csrf_protection, true)
    |> OMG.Watcher.Web.Endpoint.call([])
  end

  def create_topic(main_topic, subtopic), do: main_topic <> ":" <> subtopic

  def to_response_address(address) do
    "0X" <> encoded =
      address
      |> OMG.API.Crypto.encode_address!()
      |> String.upcase()

    encoded
  end
end
