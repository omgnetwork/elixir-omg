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

defmodule OMG.Watcher.Integration.BadChildChainServer do
  @moduledoc """
    Module useful for creating integration tests where we want to simulate byzantine child chain server
    which is returning a bad block for a particular block number.
  """

  import ExUnit.Callbacks

  defp create_module(bad_block) do
    content =
      quote do
        use JSONRPC2.Server.Handler
        alias OMG.JSONRPC.Client  # FIXME: http-client

        def port, do: 9657

        def handle_request(method, params) do
          param_hash = params["hash"]
          bad_block = get_bad_block()

          if param_hash == Base.encode16(bad_block.hash) do
            Client.encode(bad_block)
          else
            with {:ok, decoded} <- Base.decode16(param_hash, case: :mixed),
                 {:ok, response} <- Client.call(:get_block, %{hash: decoded}, "http://localhost:9656") do
              Client.encode(response)
            end
          end
        end

        defp get_bad_block, do: unquote(Macro.escape(bad_block))
      end

    # appending PID to the server name to avoid clashes of compiled modules sitting in memory (warnings)
    Module.create(:"BadChildChainServerInstance-#{inspect(self())}", content, Macro.Env.location(__ENV__))
  end

  @doc """
  This injects a bad child chain block serving into the stack, and schedules a cleanup
  Expected to be called from within test body. Can't be a fixture because of `bad_block` parameter
  """
  def register_and_start_server(bad_block) do # FIXME
    {:module, module, _, _} = create_module(bad_block)
    JSONRPC2.Servers.HTTP.http(module, port: module.port())

    Application.put_env(
      :omg_jsonrpc,
      :child_chain_url,
      "http://localhost:" <> Integer.to_string(module.port())
    )

    on_exit(fn ->
      JSONRPC2.Servers.HTTP.shutdown(module)

      Application.put_env(:omg_jsonrpc, :child_chain_url, "http://localhost:9656")
    end)
  end
end
