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

defmodule OMG.ChildChainRPC.Web.Views.Error do
  @moduledoc false
  use OMG.ChildChainRPC.Web, :view
  require Logger

  alias OMG.Utils.HttpRPC.Error
  alias OMG.ChildChainRPC.Web.Response, as: ChildChainRPCResponse

  @doc """
  Handles client errors, e.g. malformed json in request body
  """
  def render("400.json", _) do
    "operation:bad_request"
    |> Error.serialize("Server has failed to parse the request.")
    |> ChildChainRPCResponse.add_app_infos()
  end

  @doc """
  Supports internal server error thrown by Phoenix.
  """
  def render("500.json", %{reason: %{message: message}}) do
    "server:internal_server_error"
    |> Error.serialize(message)
    |> ChildChainRPCResponse.add_app_infos()
  end

  @doc """
  Renders the given error code, description and messages.
  """
  def render("error.json", %{code: code, description: description, messages: messages}) do
    code
    |> Error.serialize(description, messages)
    |> ChildChainRPCResponse.add_app_infos()
  end

  @doc """
  Renders the given error code and description.
  """
  def render("error.json", %{code: code, description: description}) do
    code
    |> Error.serialize(description)
    |> ChildChainRPCResponse.add_app_infos()
  end

  @doc """
  Renders internal server error when no render clause is matched. This is a Phoenix feature.

  See: https://github.com/phoenixframework/phoenix/blob/master/lib/phoenix/template.ex#L143-L153
  """
  def template_not_found(_template, _assigns) do
    "server:internal_server_error"
    |> Error.serialize("Server has failed to render the error.")
    |> ChildChainRPCResponse.add_app_infos()
  end
end
