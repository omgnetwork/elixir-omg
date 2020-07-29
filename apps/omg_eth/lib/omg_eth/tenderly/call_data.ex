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
defmodule OMG.Eth.Tenderly.CallData do
  @moduledoc """
  Parses call data using Tenderly
  """

  alias OMG.Eth.Encoding
  alias OMG.Eth.Tenderly.Client
  alias OMG.Eth.Tenderly.Client.SimulateRequest

  @function_names ["startStandardExit", "startInFlightExit", "challengeInFlightExitNotCanonical"]

  @doc """
  Returns call data matching any of the functions that we are parsing call data from
  """
  @spec get_call_data(binary(), module(), module()) :: {:ok, binary()} | {:error, atom()}
  def get_call_data(root_chain_tx_hash, tenderly_client \\ Client, eth_client \\ OMG.Eth.Client) do
    {:ok, transaction} = eth_client.get_transaction_by_hash(root_chain_tx_hash)
    from = Map.fetch!(transaction, "from")
    to = Map.fetch!(transaction, "to")
    input = Map.fetch!(transaction, "input")
    value = transaction |> Map.fetch!("value") |> Encoding.int_from_hex()
    block_number = transaction |> Map.fetch!("blockNumber") |> Encoding.int_from_hex()
    transaction_index = transaction |> Map.fetch!("transactionIndex") |> Encoding.int_from_hex()
    gas = transaction |> Map.fetch!("gas") |> Encoding.int_from_hex()

    simulate_request = %SimulateRequest{
      from: from,
      to: to,
      input: input,
      value: value,
      block_number: block_number,
      transaction_index: transaction_index,
      gas: gas
    }

    case tenderly_client.simulate_transaction(simulate_request) do
      {:ok, simulate_response} ->
        @function_names
        |> Enum.map(fn function_name -> get_call_data_for_function(function_name, simulate_response) end)
        |> Enum.find({:error, :no_matching_function}, &match?({:ok, _}, &1))

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_call_data_for_function(function_name, simulate_response) do
    call =
      simulate_response
      |> Map.fetch!("transaction")
      |> Map.fetch!("transaction_info")
      |> Map.fetch!("call_trace")
      |> Map.fetch!("calls")
      |> Enum.find(fn %{"function_name" => fn_name} -> fn_name == function_name end)

    if call == nil do
      {:error, :no_matching_function}
    else
      input = Map.get(call, "input")
      {:ok, input}
    end
  end
end
