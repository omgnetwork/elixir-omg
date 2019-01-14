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

defmodule OMG.RPC.Web.Controller.Block do
  @moduledoc """
  Provides endpoint action to retrieve block details of published Plasma block.
  """

  use OMG.RPC.Web, :controller
  use PhoenixSwagger

  alias OMG.RPC.Web.View

  @api_module Application.fetch_env!(:omg_rpc, :child_chain_api_module)

  def get_block(conn, params) do
    with {:ok, hex_str} <- Map.fetch(params, "hash"),
         {:ok, hash} <- Base.decode16(hex_str, case: :mixed),
         {:ok, block} <- apply(@api_module, :get_block, [hash]) do
      render(conn, View.Block, :block, block: block)
    end
  end

  def swagger_definitions do
    %{
      Block:
        swagger_schema do
          title("Block")
          description("Block details with encoded transactions")

          properties do
            blknum(:integer, "Child chain block number", required: true)
            hash(:string, "Child chain block hash", required: true)
            transactions(Schema.ref(:EncodedTransactions), "Transactions included in the block", required: true)
          end

          example(%{
            blknum: 123_000,
            hash: "2733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f",
            transactions: [
              "F849822AF880808080809400000000000000000000000000000000000000009489F5AD3F771617E853451A93F7A73E48CF5550D104948CE5C73FD5BEFFE0DCBCB6AFE571A2A3E73B043C03"
            ]
          })
        end,
      EncodedTransactions:
        swagger_schema do
          title("Encoded Transactions")
          description("Array of HEX-encoded strings of RLP-encoded transaction bytes")
          type(:array)
          items(Schema.ref(:string))
        end
    }
  end

  swagger_path :get_block do
    get("/block.get")
    summary("Retrieves a specific block from child chain which hash was published on root chain")

    parameters do
      hash(:body, :string, "HEX-encoded hash of the block", required: true)
    end

    response(200, "OK", Schema.ref(:Block))
  end
end
