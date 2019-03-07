# Copyright 2019 OmiseGO Pte Ltd
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

  alias OMG.RPC.Web.View

  @api_module Application.fetch_env!(:omg_rpc, :child_chain_api_module)

  def get_block(conn, params) do
    with {:ok, hash} <- expect(params, "hash", :hash),
         {:ok, block} <- apply(@api_module, :get_block, [hash]) do
      conn
      |> put_view(View.Block)
      |> render(:block, block: block)
    end
  end
end
