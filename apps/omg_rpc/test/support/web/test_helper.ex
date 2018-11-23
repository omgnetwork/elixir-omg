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

defmodule OMG.RPC.Web.TestHelper do
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

  def rpc_call(method, path, params_or_body \\ nil) do
    request = conn(method, path, params_or_body)
    response = request |> send_request

    assert response.status == 200

    Poison.decode!(response.resp_body)
  end

  defp send_request(req) do
    req
    |> put_private(:plug_skip_csrf_protection, true)
    |> OMG.RPC.Web.Endpoint.call([])
  end

  @spec write_fee_file(%{Crypto.address_t() => non_neg_integer}) :: {:ok, binary}
  def write_fee_file(map) do
    {:ok, json} =
      map
      |> Enum.map(fn {"0x" <> _ = k, v} -> %{token: k, flat_fee: v} end)
      |> Poison.encode()

    {:ok, path} = Briefly.create(prefix: "omisego_operator_test_fees_file")
    :ok = File.write(path, json, [:write])
    {:ok, path}
  end
end
