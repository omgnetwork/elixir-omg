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

# defmodule OMG.Watcher.Integration.BadChildChainServer do
#   @moduledoc """
#     Module useful for creating integration tests where we want to simulate byzantine child chain server
#     which is returning a bad block for a particular block hash.
#   """

#   alias OMG.Block
#   alias OMG.Utils.HttpRPC.Adapter
#   alias OMG.Utils.HttpRPC.Encoding
#   alias OMG.Utils.HttpRPC.Response
#   alias OMG.Watcher.Integration.TestServer

#   @doc """
#   Adds a route to TestServer which responded with prepared bad block when asked for known hash
#   all other requests are redirected to `real` Child Chain API
#   """
#   def prepare_route_to_inject_bad_block(context, bad_block, bad_block_hash) do
#     TestServer.with_route(
#       context,
#       "/block.get",
#       fn %{body: params} ->
#         {:ok, %{"hash" => req_hash}} = Jason.decode(params)

#         if {:ok, bad_block_hash} == Encoding.from_hex(req_hash) do
#           bad_block
#           |> Block.to_api_format()
#           |> Response.sanitize()
#           |> TestServer.make_response()
#         else
#           {:ok, block} =
#             %{hash: req_hash}
#             |> Adapter.rpc_post("block.get", context.real_addr)
#             |> Adapter.get_response_body()

#           TestServer.make_response(block)
#         end
#       end
#     )
#   end

#   @doc """
#   Version of `prepare_route_to_inject_bad_block/3` when we want to serve the block under it's real hash
#   """
#   def prepare_route_to_inject_bad_block(context, %{hash: bad_block_hash} = bad_block) do
#     prepare_route_to_inject_bad_block(context, bad_block, bad_block_hash)
#   end
# end
