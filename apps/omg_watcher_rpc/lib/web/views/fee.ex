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

defmodule OMG.WatcherRPC.Web.View.Fee do
  @moduledoc """
  The challenge view for rendering json
  """

  use OMG.WatcherRPC.Web, :view
  alias OMG.Utils.HttpRPC.Response

  def render("fees_all.json", %{response: fees}) do
    fees
    |> Enum.map(&parse_for_type/1)
    |> Enum.into(%{})
    |> Response.serialize()
  end

  defp parse_for_type({tx_type, fees}) do
    {tx_type, Enum.map(fees, &parse_for_token/1)}
  end

  defp parse_for_token(fee) do
    fee
    |> Map.put("currency", {:skip_hex_encode, fee["currency"]})
    |> Map.put("pegged_currency", {:skip_hex_encode, fee["pegged_currency"]})
    |> Map.put("updated_at", {:skip_hex_encode, fee["updated_at"]})
  end
end
