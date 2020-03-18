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

defmodule OMG.ChildChain.BlockQueue.GasAnalyzer do
  @moduledoc """
    Takes the transaction hash and puts it in the  FIFO queue
  for each transaction hash we're trying to get the gas we've used to submit the block and send it of as a telemetry event
  to datadog
  """
  require Logger

  defstruct txhash_queue: :queue.new(), rpc: Ethereumex.HttpClient

  def enqueue(server \\ __MODULE__, txhash) do
    GenServer.cast(server, {:enqueue, txhash})
  end

  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      type: :worker
    }
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(_args) do
    _ = :timer.send_after(3000, self(), :get_gas_used)
    {:ok, %__MODULE__{}}
  end

  def handle_cast({:enqueue, txhash}, state) do
    {:noreply, %{state | txhash_queue: :queue.in(txhash, state.txhash_queue)}}
  end

  def handle_info(:get_gas_used, state) do
    txhash_queue =
      case :queue.is_empty(state.txhash_queue) do
        true ->
          state.txhash_queue

        false ->
          {{:value, txhash}, txhash_queue} = state.txhash_queue |> :queue.out()
          gas_used = txhash |> to_hex() |> get_gas_used(state.rpc)

          case gas_used do
            nil ->
              :queue.in_r(txhash, txhash_queue)

            gas ->
              _ = :telemetry.execute([:gas, __MODULE__], %{gas: gas}, %{})
              txhash_queue
          end
      end

    _ = :timer.send_after(3000, self(), :get_gas_used)
    {:noreply, %{state | txhash_queue: txhash_queue}}
  end

  defp get_gas_used(receipt_hash, rpc) do
    result = {rpc.eth_get_transaction_receipt(receipt_hash), rpc.eth_get_transaction_by_hash(receipt_hash)}

    case result do
      {{:ok, %{"gasUsed" => gas_used}}, {:ok, %{"gasPrice" => gas_price}}} ->
        gas_price_value = parse_gas(gas_price)
        gas_used_value = parse_gas(gas_used)
        gas_used = gas_price_value * gas_used_value
        _ = Logger.info("Block submitted with receipt hash #{receipt_hash} and gas used #{gas_used}wei")
        gas_used

      {eth_get_transaction_receipt, eth_get_transaction_by_hash} ->
        _ =
          Logger.error(
            "Could not get gas used for receipt_hash #{receipt_hash}. Eth_get_transaction_receipt result #{
              inspect(eth_get_transaction_receipt)
            }. Eth_get_transaction_by_hash result #{inspect(eth_get_transaction_by_hash)}."
          )

        nil
    end
  end

  defp to_hex(raw) when is_binary(raw), do: "0x" <> Base.encode16(raw, case: :lower)

  defp parse_gas(data) do
    {value, ""} = data |> String.replace_prefix("0x", "") |> Integer.parse(16)
    value
  end
end
