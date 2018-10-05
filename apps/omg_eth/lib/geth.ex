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

defmodule OMG.Eth.Geth do
  @moduledoc """
  Tracks state of local geth
  """

  @spec node_ready() :: :ok | {:error, :geth_still_syncing | :geth_not_listening}
  def node_ready do
    case Ethereumex.HttpClient.eth_syncing() do
      {:ok, false} -> :ok
      {:ok, true} -> {:error, :geth_still_syncing}
      {:error, :econnrefused} -> {:error, :geth_not_listening}
    end
  end

  @doc """
  Checks geth syncing status, errors are treated as not synced.
  Returns:
  * false - geth is synced
  * true  - geth is still syncing.
  """
  @spec syncing?() :: boolean
  def syncing?, do: node_ready() != :ok
end
