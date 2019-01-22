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

defmodule OMG.RPC.Web.Controller.Fallback do
  @moduledoc """
  The fallback handler.

  TODO: Intentionally we want to have single Phx app exposing both APIs, until then please keep this file similar
  to the corresponding Watcher's one to make merge simpler.
  """

  use Phoenix.Controller

  alias OMG.RPC.Web.Error

  @errors %{}

  def call(conn, :not_found), do: json(conn, Error.serialize(:endpoint_not_found, "Endpoint not found"))

  def call(conn, {:error, {:validation_error, param_name, validator}}) do
    response =
      Error.serialize(
        "#{action_name(conn)}:bad_request",
        "Parameters required by this action are missing or incorrect.",
        %{validation_error: %{parameter: param_name, validator: inspect(validator)}}
      )

    json(conn, response)
  end

  def call(conn, {:error, reason}) do
    err_info =
      @errors
      |> Map.get(
        reason,
        %{code: "#{action_name(conn)}#{inspect(reason)}", description: nil}
      )

    respond(conn, err_info)
  end

  def call(conn, :error), do: call(conn, {:error, :unknown_error})

  # Controller's action with expression has no match, e.g. on guard
  def call(conn, _), do: call(conn, {:error, :unknown_error})

  defp respond(conn, %{code: code, description: description}) do
    json(conn, Error.serialize(code, description))
  end
end
