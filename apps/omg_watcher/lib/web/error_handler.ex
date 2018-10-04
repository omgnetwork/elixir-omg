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

defmodule OMG.Watcher.Web.ErrorHandler do
  @moduledoc """
  Handles API errors by mapping the error to its response code and description.
  """
  alias OMG.Watcher.Web.Serializer

  import Plug.Conn, only: [halt: 1]
  import Phoenix.Controller, only: [json: 2]

  @errors %{
    invalid_challenge_of_exit: %{
      code: "challenge:invalid",
      description: "The challenge of particular exit is invalid because provided utxo is not spent",
      status_code: 400
    },
    transaction_not_found: %{
      code: "transaction:not_found",
      description: "Transaction doesn't exist for provided search criteria",
      status_code: 404
    },
    too_many_inputs: %{
      code: "transaction_encode:too_many_inputs",
      description: "More inputs provided than currently supported by plasma chain transaction.",
      status_code: 400
    },
    at_least_one_input_required: %{
      code: "transaction_encode:at_least_one_input_required",
      description: "At least one input has to be provided to create plasma chain transaction.",
      status_code: 400
    },
    too_many_outputs: %{
      code: "transaction_encode:too_many_outputs",
      description: "More outputs provided than currently supported by plasma chain transaction.",
      status_code: 400
    },
    not_enough_funds_to_cover_spend: %{
      code: "transaction_encode:not_enough_funds_to_cover_spend",
      description: "The value of outputs exceeds what is spent in inputs.",
      status_code: 400
    },
    amount_noninteger_or_negative: %{
      code: "transaction_encode:amount_noninteger_or_negative",
      description: "The amount in both inputs and outputs has to be non-negative integer.",
      status_code: 400
    },
    currency_mixing_not_possible: %{
      code: "transaction_encode:currency_mixing_not_possible",
      description:
        "Inputs contain more than one currency. Mixing currencies is not possible in plasma chain transaction.",
      status_code: 400
    }
  }

  @doc """
  Handles response with custom error code, description and status_code.
  """
  @spec handle_error(Plug.Conn.t(), atom(), String.t(), pos_integer()) :: Plug.Conn.t()
  def handle_error(conn, code, description, status_code) do
    response = build(code, description)

    conn
    |> Plug.Conn.put_status(status_code)
    |> respond(response)
  end

  @doc """
  Handles response with default error code and description
  """
  @spec handle_error(Plug.Conn.t(), atom()) :: Plug.Conn.t()
  def handle_error(conn, code) do
    {status_code, response} =
      case Map.fetch(@errors, code) do
        {:ok, error} ->
          {error.status_code, build(error.code, error.description)}

        _ ->
          {500, build(:internal_server_error, code)}
      end

    conn
    |> Plug.Conn.put_status(status_code)
    |> respond(response)
  end

  defp build(code, description) do
    Serializer.Error.serialize(code, description)
  end

  defp respond(conn, data) do
    data = Serializer.Response.serialize(data, :error)

    conn
    |> json(data)
    |> halt()
  end
end
