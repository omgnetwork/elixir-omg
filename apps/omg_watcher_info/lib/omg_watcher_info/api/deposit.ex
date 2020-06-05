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

defmodule OMG.WatcherInfo.API.Deposit do
  @moduledoc """
  Module provides operations related to deposits.
  """

  alias OMG.Utils.Paginator
  alias OMG.WatcherInfo.DB

  @default_events_limit 100

  @doc """
  Retrieves a list of deposits.
  Length of the list is limited by `limit` and `page` arguments.
  """
  @spec get_deposits(Keyword.t()) :: Paginator.t(%DB.EthEvent{})
  def get_deposits(constraints) do
    {:ok, address} = Keyword.fetch(constraints, :address)

    constraints
    |> Paginator.from_constraints(@default_events_limit)
    |> DB.EthEvent.get_deposits(address)
  end
end
