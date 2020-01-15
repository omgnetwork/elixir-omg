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
  Use with :test_server fixture which provides context variables
  For now it's strictly tied with child chain api and handles env variable changes
  """

  alias FakeServer.Agents.EnvAgent
  alias FakeServer.HTTP.Server

  @doc """
  Configures route for fake server to respond for given path with given response
  **Please note: **
  When the route is configured with a list of FakeServer.HTTP.Responses, the server will respond with the first element
  in the list and then remove it. This will be repeated for each request made for this route.
  Use `fn req -> response end` when you need to return always the same or modified response on every request

  Also first use of `with_route` changes configuration variable to child chain api to fake server, so invoke this
  function when fake response is needed.
  """
  def with_route(%{fake_addr: fake_addr, server_id: server_id} = _context, path, response_block) do
    Application.put_env(:omg_watcher_info, :child_chain_url, fake_addr)
    env = EnvAgent.get_env(server_id)
    _ = EnvAgent.save_env(server_id, %FakeServer.Env{env | routes: [path | env.routes]})
    Server.add_response(server_id, path, response_block)
  end

  def make_response(data) when is_map(data),
    do:
      FakeServer.HTTP.Response.ok(%{
        version: "1.0",
        success: not Map.has_key?(data, :code),
        data: data
      })
end
