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

defmodule OMG.WatcherRPC.Web.Controller.Account do
  @moduledoc """
  Module provides operation related to plasma accounts.
  """

  use OMG.WatcherRPC.Web, :controller

  alias OMG.Watcher.API, as: SecurityAPI
  alias OMG.WatcherInfo.API, as: InfoAPI
  alias OMG.WatcherRPC.Web.Validator.AccountConstraints

  @doc """
  Gets plasma account balance
  """
  def get_balance(conn, params) do
    with {:ok, address} <- expect(params, "address", :address) do
      address
      |> InfoAPI.Account.get_balance()
      |> api_response(conn, :balance)
    end
  end

  def get_utxos(conn, params) do
    with {:ok, constraints} <- AccountConstraints.parse(params) do
      constraints
      |> InfoAPI.Account.get_utxos()
      |> api_response(conn, :utxos)
    end
  end

  def get_exitable_utxos(conn, params) do
    with {:ok, address} <- expect(params, "address", :address) do
      address
      |> SecurityAPI.Account.get_exitable_utxos()
      |> api_response(conn, :exitable_utxos)
    end
  end
end
