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

defmodule OMG.Watcher.Integration.BadChildChainBLock do
  @moduledoc """
    Module useful for creating integration tests where we want to simulate byzantine child chain server
    which is returning a bad block for a particular block number.
  """

  def create_module(bad_block) do
    content =
      quote do
        use JSONRPC2.Server.Handler
        alias OMG.JSONRPC.Client

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

    Module.create(BadChildChainBLock, content, Macro.Env.location(__ENV__))
  end
end
