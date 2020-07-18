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

defmodule OMG.WatcherRPC.Web.Plugs.MethodAllow do
  @moduledoc """
  Allows when the HTTP request method is either `GET` or `POST`.
  Otherwise, halt the request from getting passed through plugs.
  """

  import Plug.Conn, only: [halt: 1]
  alias Phoenix.Controller
  alias OMG.Utils.HttpRPC.Error

  @allowed_http_methods ["GET", "POST"]

  def init(args), do: args

  def call(%Plug.Conn{method: method} = conn, _) when method in @allowed_http_methods, do: conn

  def call(%Plug.Conn{method: method} = conn, _) do
    data =
      Error.serialize(
        "operation:method_not_allowed",
        "#{method} is not allowed."
      )

    conn
    |> Controller.json(data)
    |> halt()
  end
end
