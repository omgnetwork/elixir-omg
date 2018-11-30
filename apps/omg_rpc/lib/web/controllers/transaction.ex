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
  # TODO: @moduledoc false

  use OMG.RPC.Web, :controller
  use PhoenixSwagger

  alias OMG.RPC.Web.View

  @api_module Application.fetch_env!(:omg_rpc, :child_chain_api_module)

  action_fallback(OMG.RPC.Web.Controller.Fallback)

  def submit(conn, params) do
    with {:ok, hex_str} <- Map.fetch(params, "transaction"),
         {:ok, txbytes} <- Base.decode16(hex_str, case: :mixed),
         {:ok, details} <- @api_module.submit(txbytes) do
      render(conn, View.Transaction, :submit, result: details)
    end
  end

  # FIXME: swagger definitions
end
