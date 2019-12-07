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

defmodule OMG.WatcherRPC.Web.Views.Error do
  @moduledoc false
  use OMG.WatcherRPC.Web, :view
  use OMG.Utils.LoggerExt

  alias OMG.Utils.HttpRPC.Error

  @doc """
  Handles client errors, e.g. malformed json in request body
  """
  def render("400.json", _) do
    Error.serialize("operation:bad_request", "Server has failed to parse the request.", %{})
  end

  @doc """
  Supports internal server error thrown by Phoenix.
  """
  def render("500.json", %{reason: %{message: message}} = _conn) do
    Error.serialize("server:internal_server_error", message, %{})
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, _assigns) do
    Error.serialize("server:internal_server_error", nil, %{})
  end
end
