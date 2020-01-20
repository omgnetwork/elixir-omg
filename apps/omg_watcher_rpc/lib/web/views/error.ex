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

defmodule OMG.WatcherRPC.Web.Views.Error do
  @moduledoc """
  The error view for rendering json
  """

  use OMG.WatcherRPC.Web, :view
  use OMG.Utils.LoggerExt

  alias OMG.Utils.HttpRPC.Error
  alias OMG.WatcherRPC.Web.Response, as: WatcherRPCResponse

  @doc """
  Handles client errors, e.g. malformed json in request body
  """
  def render("400.json", _) do
    "operation:bad_request"
    |> Error.serialize("Server has failed to parse the request.")
    |> WatcherRPCResponse.add_app_infos()
  end

  @doc """
  Supports internal server error thrown by Phoenix.
  """
  def render("500.json", %{reason: %{message: message}} = _conn) do
    "server:internal_server_error"
    |> Error.serialize(message)
    |> WatcherRPCResponse.add_app_infos()
  end

  @doc """
  Renders the given error code, description and messages.
  """
  def render("error.json", %{code: code, description: description, messages: messages}) do
    code
    |> Error.serialize(description, messages)
    |> WatcherRPCResponse.add_app_infos()
  end

  @doc """
  Renders the given error code and description.
  """
  def render("error.json", %{code: code, description: description}) do
    code
    |> Error.serialize(description)
    |> WatcherRPCResponse.add_app_infos()
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, _assigns) do
    "server:internal_server_error"
    |> Error.serialize("Server has failed to render the error.")
    |> WatcherRPCResponse.add_app_infos()
  end
end
