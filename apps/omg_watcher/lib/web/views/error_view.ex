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

defmodule OMG.Watcher.Web.View.ErrorView do
  use OMG.Watcher.Web, :view
  use OMG.LoggerExt

  alias OMG.RPC.Web.Error

  @doc """
  Handles client errors, e.g. malformed json in request body
  """
  def render("400.json", %{reason: reason, conn: conn}) do
    _ =
      Logger.warn(
        "Malformed request. #{inspect(Map.get(conn, :request_path, "<undefined path>"))}\nReason: #{inspect(reason)}"
      )

    Error.serialize(
      "operation:bad_request",
      "Server has failed to parse the request.",
      # add stack trace unless running on production env
      if(Mix.env() in [:dev, :test], do: "#{inspect(reason)}")
    )
  end

  @doc """
  Supports internal server error thrown by Phoenix.
  """
  def render("500.json", %{reason: %{message: message}} = conn) do
    Error.serialize(
      "server:internal_server_error",
      message,
      # add stack trace unless running on production env
      if(Mix.env() in [:dev, :test], do: "#{inspect(Map.get(conn, :stack))}")
    )
  end

  @doc """
  Renders error when no render clause matches or no template is found.
  """
  def template_not_found(_template, %{reason: reason} = conn) do
    _ = Logger.error("Unhandled error occurred most likely in controller / API layer: #{inspect(conn)}")

    throw(
      "Unmatched render clause for template #{inspect(Map.get(reason, :template, "<unable to find>"))} in #{
        inspect(Map.get(reason, :module, "<unable to find>"))
      }"
    )
  end
end
