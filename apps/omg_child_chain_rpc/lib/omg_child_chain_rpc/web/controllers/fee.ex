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

defmodule OMG.ChildChainRPC.Web.Controller.Fee do
  @moduledoc """
  Operations related to fees.
  """

  use OMG.ChildChainRPC.Web, :controller
  plug(OMG.ChildChainRPC.Plugs.Health)
  alias OMG.ChildChain

  def fees_all(conn, params) do
    with {:ok, currencies} <- expect(params, "currencies", list: &to_currency/1, optional: true),
         {:ok, tx_types} <- expect(params, "tx_types", list: &to_tx_type/1, optional: true),
         {:ok, filtered_fees} <- ChildChain.get_filtered_fees(tx_types, currencies) do
      api_response(filtered_fees, conn, :fees_all)
    end
  end

  defp to_currency(currency_str) do
    expect(%{"currency" => currency_str}, "currency", :address)
  end

  defp to_tx_type(tx_type_str) do
    expect(%{"tx_type" => tx_type_str}, "tx_type", :non_neg_integer)
  end
end
