# Copyright 2019-2019 OmiseGO Pte Ltd
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

defmodule OMG.Eth.ReleaseTasks.SetEthereumClient do
  @moduledoc false
  use Distillery.Releases.Config.Provider

  @doc """
  Gets the environment setting for the ethereum client location.
  """
  @impl Provider
  def init(_args) do
    case get_env("ETHEREUM_RPC_URL") do
      url when is_binary(url) -> Application.put_env(:ethereumex, :url, url, persistent: true)
      _ -> Application.put_env(:ethereumex, :url, "http://localhost:8545", persistent: true)
    end

    :ok
  end

  defp get_env(key), do: System.get_env(key)
end
