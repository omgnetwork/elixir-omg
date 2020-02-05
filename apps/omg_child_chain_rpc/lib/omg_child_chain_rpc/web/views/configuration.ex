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

defmodule OMG.ChildChainRPC.Web.View.Configuration do
  @moduledoc """
  The Configuration view for rendering json
  """

  alias OMG.ChildChainRPC.Web.Response, as: ChildChainRPCResponse
  alias OMG.Utils.HttpRPC.Response

  def render("configuration.json", %{response: configuration}) do
    configuration
    |> to_api_format()
    |> Response.serialize()
    |> ChildChainRPCResponse.add_app_infos()
  end

  defp to_api_format(%{contract_semver: contract_semver, network: network} = response) do
    response
    |> Map.put(:contract_semver, {:skip_hex_encode, contract_semver})
    |> Map.put(:network, {:skip_hex_encode, network})
  end
end
