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

defmodule OMG.ChildChainRPC.Web.Controller.Fallback do
  @moduledoc """
  The fallback handler.
  """

  use Phoenix.Controller

  alias OMG.ChildChainRPC.Web.Views

  @errors %{
    tx_type_not_supported: %{
      code: "fee:tx_type_not_supported",
      description: "One or more of the given transaction types are not supported."
    },
    currency_fee_not_supported: %{
      code: "fee:currency_fee_not_supported",
      description: "One or more of the given currencies are not supported as a fee-token."
    },
    operation_not_found: %{
      code: "operation:not_found",
      description: "Operation cannot be found. Check request URL."
    },
    operation_bad_request: %{
      code: "operation:bad_request",
      description: "Parameters required by this operation are missing or incorrect."
    }
  }

  def call(conn, Route.NotFound), do: call(conn, {:error, :operation_not_found})

  def call(conn, {:error, {:validation_error, param_name, validator}}) do
    error = error_info(conn, :operation_bad_request)

    conn
    |> put_view(Views.Error)
    |> render(:error, %{
      code: error.code,
      description: error.description,
      messages: %{validation_error: %{parameter: param_name, validator: inspect(validator)}}
    )
  end

  def call(conn, {:error, reason}) do
    error = error_info(conn, reason)

    conn
    |> put_view(Views.Error)
    |> render(:error, %{code: error.code, description: error.description)
  end

  def call(conn, :error), do: call(conn, {:error, :unknown_error})

  # Controller's action with expression has no match, e.g. on guard
  def call(conn, _), do: call(conn, {:error, :unknown_error})

  defp error_info(conn, reason) do
    case Map.get(@errors, reason) do
      nil -> %{code: "#{action_name(conn)}#{inspect(reason)}", description: nil}
      error -> error
    end
  end
end
