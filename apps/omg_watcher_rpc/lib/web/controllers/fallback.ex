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
  alias OMG.WatcherRPC.Web.Views

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
    deposit_input_spent_ife_unsupported: %{
      code: "in_flight_exit:deposit_input_spent_ife_unsupported",
      description: "Retrieving IFE data of a transaction with a spent deposit is unsupported."
    },
    econnrefused: %{
      code: "connection:econnrefused",
      description: "Cannot connect to the Ethereum node."
    },
    childchain_unreachable: %{
      code: "connection:childchain_unreachable",
      description: "Cannot communicate with the childchain."
    },
    insufficient_funds: %{
      code: "transaction.create:insufficient_funds",
      description: "Account balance is too low to satisfy the payment."
    },
    too_many_inputs: %{
      code: "transaction.create:too_many_inputs",
      description: "The number of inputs required to cover the payment and fee exceeds the maximum allowed."
    },
    too_many_outputs: %{
      code: "transaction.create:too_many_outputs",
      description: "Total number of payments + change + fees exceed maximum allowed outputs."
    },
    single_input: %{
      code: "merge:single_input",
      description: "Only one input found for the given address and currency."
    },
    empty_transaction: %{
      code: "transaction.create:empty_transaction",
      description: "Requested payment transfers no funds."
    },
    self_transaction_not_supported: %{
      code: "transaction.create:self_transaction_not_supported",
      description: "This endpoint cannot be used to create merge or split transactions."
    },
    invalid_merkle_root: %{
      code: "block.validate:invalid_merkle_root",
      description: "Block hash does not match reconstructed Merkle root."
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

  def call(conn, {:error, {:validation_error, param_name, validator}}) do
    error = error_info(conn, :operation_bad_request)

    conn
    |> put_view(Views.Error)
    |> render(:error, %{
      code: error.code,
      description: error.description,
      messages: %{validation_error: %{parameter: param_name, validator: inspect(validator)}}
    })
  end

  def call(conn, {:error, {reason, data}}) do
    error = error_info(conn, reason)

    conn
    |> put_view(Views.Error)
    |> render(:error, %{code: error.code, description: error.description, messages: data})
  end

  def call(conn, {:error, reason}) do
    error = error_info(conn, reason)

    conn
    |> put_view(Views.Error)
    |> render(:error, %{code: error.code, description: error.description})
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
