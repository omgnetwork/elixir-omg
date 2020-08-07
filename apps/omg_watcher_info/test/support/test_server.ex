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

defmodule OMG.WatcherInfo.TestServer do
  @moduledoc """
  Helper functions to provide behavior to FakeServer without using FakeServer defined macros.
  For now it's strictly tied with child chain api and handles env variable changes
  """

  @doc """
  Starts a mock server that will handle child chain requests
  """
  def start() do
    server_id = :watcher_info_test_server
    {:ok, pid} = FakeServer.start(server_id)

    real_addr = Application.fetch_env!(:omg_watcher_info, :child_chain_url)
    {:ok, port} = FakeServer.port(server_id)
    fake_addr = "http://localhost:#{port}"

    %{
      real_addr: real_addr,
      fake_addr: fake_addr,
      server_id: server_id,
      server_pid: pid
    }
  end

  @doc """
  Stops a server and put back the original child chain address to the env.
  """
  def stop(%{real_addr: real_addr, server_id: server_id}) do
    Application.put_env(:omg_watcher_info, :child_chain_url, real_addr)
    FakeServer.stop(server_id)
  end

  @doc """
  Configures route for fake server to respond for given path with given response
  **Please note: **
  When the route is configured with a list of FakeServer.HTTP.Responses, the server will respond with the first element
  in the list and then remove it. This will be repeated for each request made for this route.
  Use `fn req -> response end` when you need to return always the same or modified response on every request

  Also first use of `with_response` changes configuration variable to child chain api to fake server, so invoke this
  function when fake response is needed.
  """
  def with_response(response_block, %{fake_addr: fake_addr, server_pid: server_pid} = _context, path) do
    Application.put_env(:omg_watcher_info, :child_chain_url, fake_addr)

    FakeServer.put_route(server_pid, path, fn _ ->
      response_block
    end)
  end

  def make_response(data) when is_map(data) do
    TestServerResponseFactory.build(:json_rpc, data: data, success: not Map.has_key?(data, :code))
  end
end

defmodule TestServerResponseFactory do
  @moduledoc false
  use FakeServer.ResponseFactory

  def json_rpc_response() do
    ok(
      %{
        version: "1.0",
        success: true,
        data: %{}
      },
      %{"Content-Type" => "application/json"}
    )
  end
end
