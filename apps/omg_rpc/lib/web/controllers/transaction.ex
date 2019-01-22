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

defmodule OMG.RPC.Web.Controller.Transaction do
  @moduledoc """
  Provides endpoint action to submit transaction to the Child Chain.
  """

  use OMG.RPC.Web, :controller
  use PhoenixSwagger

  alias OMG.RPC.Web.View

  @api_module Application.fetch_env!(:omg_rpc, :child_chain_api_module)

  def submit(conn, params) do
    with {:ok, txbytes} <- expect(params, "transaction", :hex),
         {:ok, details} <- apply(@api_module, :submit, [txbytes]) do
      render(conn, View.Transaction, :submit, result: details)
    end
  end

  def swagger_definitions do
    %{
      TransactionSubmission:
        swagger_schema do
          title("Block")
          description("Block details with encoded transctions")

          properties do
            blknum(:integer, "Child chain block number", required: true)
            txindex(:integer, "Index of the transaction in the block", required: true)
            txhash(:string, "Child chain block hash", required: true)
          end

          example(%{
            blknum: 123_000,
            txindex: 111,
            txhash: "2733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f"
          })
        end
    }
  end

  swagger_path :get_block do
    get("/transaction.submit")
    summary("Submits signed transaction to the child chain")

    parameters do
      transaction(:body, :string, "Signed transaction RLP-encoded to bytes and HEX-encoded to string", required: true)
    end

    response(200, "OK", Schema.ref(:TransactionSubmission))
  end
end
