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

defmodule OMG.WatcherRPC.Web.Controller.Fallback do
  @moduledoc """
  The fallback handler.
  """

  use Phoenix.Controller
  alias OMG.Utils.HttpRPC.Error

  @errors %{
    exit_not_found: %{
      code: "challenge:exit_not_found",
      description: "The challenge of particular exit is impossible because exit is inactive or missing"
    },
    utxo_not_spent: %{
      code: "challenge:utxo_not_spent",
      description: "The challenge of particular exit is impossible because provided utxo is not spent"
    },
    transaction_not_found: %{
      code: "transaction:not_found",
      description: "Transaction doesn't exist for provided search criteria"
    },
    utxo_not_found: %{
      code: "exit:invalid",
      description: "Utxo was spent or does not exist."
    },
    tx_for_input_not_found: %{
      code: "in_flight_exit:tx_for_input_not_found",
      description: "No transaction that created input."
    },
    econnrefused: %{
      code: "get_status:econnrefused",
      description: "Cannot connect to the Ethereum node."
    },
    insufficient_funds: %{
      code: "transaction.create:insufficient_funds",
      description: "Account balance is too low to satisfy the payment."
    },
    too_many_outputs: %{
      code: "transaction.create:too_many_outputs",
      description: "Total number of payments + change + fees exceed maximum allowed outputs."
    },
    empty_transaction: %{
      code: "transaction.create:empty_transaction",
      description: "Requested payment transfers no funds."
    },
    missing_signature: %{
      code: "submit_typed:missing_signature",
      description:
        "Signatures should correspond to inputs owner. When all non-empty inputs has the same owner, " <>
          "signatures should be duplicated."
    },
    superfluous_signature: %{
      code: "submit_typed:superfluous_signature",
      description: "Number of non-empty inputs should match signatures count. Remove redundant signatures."
    },
    no_deposit_for_given_blknum: %{
      code: "exit:invalid",
      description: "Utxo was spent or does not exist."
    }
  }

  def call(conn, Route.NotFound),
    do: json(conn, Error.serialize("operation:not_found", "Operation cannot be found. Check request URL."))

  def call(conn, {:error, {:validation_error, param_name, validator}}) do
    response =
      Error.serialize(
        "operation:bad_request",
        "Parameters required by this operation are missing or incorrect.",
        %{validation_error: %{parameter: param_name, validator: inspect(validator)}}
      )

    json(conn, response)
  end

  def call(conn, {:error, {reason, data}}) do
    error = error_info(conn, reason)
    respond(conn, Map.put(error, :messages, data))
  end

  def call(conn, {:error, reason}), do: respond(conn, error_info(conn, reason))

  def call(conn, :error), do: call(conn, {:error, :unknown_error})

  # Controller's action with expression has no match, e.g. on guard
  def call(conn, _), do: call(conn, {:error, :unknown_error})

  defp respond(conn, %{code: code, description: description} = err_info) do
    json(conn, Error.serialize(code, description, Map.get(err_info, :messages)))
  end

  defp error_info(conn, reason),
    do:
      @errors
      |> Map.get(reason, %{code: "#{action_name(conn)}#{inspect(reason)}", description: nil})
end
