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

defmodule OMG.Watcher.Web.Controller.Account do
  @moduledoc """
  Module provides operation related to plasma accounts.
  """

  use OMG.Watcher.Web, :controller
  use PhoenixSwagger

  alias OMG.API.State
  alias OMG.Eth
  alias OMG.Watcher.Web.View

  import OMG.Watcher.Web.ErrorHandler

  @doc """
  Gets plasma account balance
  """
  def get_balance(conn, _params) do

    respond({:ok, []}, conn)
  end

  defp respond({:ok, balance}, conn) do
    render(conn, View.Account, :balance, balance: balance)
  end

  defp respond({:error, code}, conn) do
    handle_error(conn, code)
  end

  def swagger_definitions do
    %{ }
  end

  swagger_path :get_status do
    get("/account/{address}/balance")
    summary("Responds with account balance for given account address")

    parameters do
      utxo_pos(:path, :string, "Address of funds owner", required: true)
    end

    response(200, "OK", Schema.ref(:Balance))
  end
end
