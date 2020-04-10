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

defmodule OMG.ChildChainRPC.Web.Plugs.MethodParamFilter do
  @moduledoc """
  Filters the `query_params`, `body_params` and `params` of the conn
  depending on the HTTP method used.

  For a POST: `query_params` will be ignored and `body_params` will be
  set to `params`.

  For a GET: `body_params` will be ignored and `query_params` will be
  set to `params`.
  """

  def init(args), do: args

  def call(%Plug.Conn{method: "POST", body_params: params} = conn, _) do
    conn
    |> Map.put(:query_params, %{})
    |> Map.put(:params, params)
  end

  def call(%Plug.Conn{method: "GET", query_params: params} = conn, _) do
    conn
    |> Map.put(:body_params, %{})
    |> Map.put(:params, params)
  end
end
