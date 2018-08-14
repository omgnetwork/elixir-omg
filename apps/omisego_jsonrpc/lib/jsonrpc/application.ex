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

defmodule OmiseGO.JSONRPC.Application do
  @moduledoc false

  use Application
  use OmiseGO.API.LoggerExt

  def start(_type, _args) do
    omisego_port = Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port)

    children = [
      JSONRPC2.Servers.HTTP.child_spec(:http, OmiseGO.JSONRPC.Server.Handler, port: omisego_port)
    ]

    _ = Logger.info(fn -> "Started application OmiseGO.JSONRPC.Application" end)
    opts = [strategy: :one_for_one, name: OmiseGO.JSONRPC.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
