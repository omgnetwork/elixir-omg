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

defmodule OMG.WatcherRPC.Web.Controller.EthEvent do
  @moduledoc """
  Operations related to transaction.
  """

  use OMG.WatcherRPC.Web, :controller

  alias OMG.WatcherInfo.API.EthEvent, as: InfoApiEthEvent
  alias OMG.WatcherRPC.Web.Validator

  @doc """
  Retrieves a list of transactions
  """
  def get_deposits(conn, params) do
    with {:ok, constraints} <- Validator.EthEventConstraints.parse(params) do
      constraints
      |> InfoApiEthEvent.get_deposits()
      |> api_response(conn, :ethevents)
    end
  end
end
