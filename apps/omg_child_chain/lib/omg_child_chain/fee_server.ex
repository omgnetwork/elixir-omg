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

defmodule OMG.ChildChain.FeeServer do
  @moduledoc """
  Maintains current fee rates and tokens in which fees may be paid.

  Periodically updates fees information from an external source (defined in config
  by fee_adapter) until switched off with config :omg_child_chain, :ignore_fees.

  Fee's file parsing and rules of transaction's fee validation are in `OMG.Fees`
  """
  use GenServer
  use OMG.Utils.LoggerExt

  alias OMG.Fees
  alias OMG.Status.Alert.Alarm

  @fee_file_check_interval_ms Application.fetch_env!(:omg_child_chain, :fee_file_check_interval_ms)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(args) do
    :ok = ensure_ets_init()

    # This will crash the process by returning {:error, :fee_adapter_not_defined}
    # if the fee_adapter is not set in the config
    {:ok, fee_adapter} = get_fee_adapter()
    args = Keyword.put(args, :fee_adapter, fee_adapter)

    args =
      case Application.get_env(:omg_child_chain, :ignore_fees) do
        true ->
          :ok = save_fees(:no_fees_required, 0)
          _ = Logger.warn("Fees are ignored.")
          args

        opt when is_nil(opt) or is_boolean(opt) ->
          :ok = update_fee_specs(fee_adapter)
          interval = Keyword.get(args, :interval_ms, @fee_file_check_interval_ms)
          {:ok, tref} = :timer.send_interval(interval, self(), :update_fee_specs)
          Keyword.put(args, :tref, tref)
      end

    _ = Logger.info("Started #{inspect(__MODULE__)}")

    {:ok, args}
  end

  @doc """
  Returns accepted tokens and amounts in which transaction fees are collected for each transaction type
  """
  @spec transaction_fees() :: {:ok, %{String.t() => [Fees.fee_t()]}}
  def transaction_fees() do
    {:ok, load_fees()}
  end

  def handle_info(:update_fee_specs, state) do
    _ =
      case Application.get_env(:omg_child_chain, :ignore_fees) do
        true ->
          _ = Logger.warn("Fees are ignored. Updates have no effect.")

        _ ->
          case update_fee_specs(state[:fee_adapter]) do
            :ok ->
              Alarm.clear(Alarm.invalid_fee_file(__MODULE__))

            _ ->
              Alarm.set(Alarm.invalid_fee_file(__MODULE__))
          end
      end

    {:noreply, state}
  end

  @spec update_fee_specs(module()) :: :ok | {:error, atom() | [{:error, atom()}, ...]}
  defp update_fee_specs(adapter) do
    source_updated_at = :ets.lookup_element(:fees_bucket, :fee_specs_source_updated_at, 2)

    case adapter.get_fee_specs(source_updated_at) do
      {:ok, fee_specs, source_updated_at} ->
        :ok = save_fees(fee_specs, source_updated_at)
        _ = Logger.info("Reloaded #{inspect(Enum.count(fee_specs))} fee specs from
                         #{inspect(adapter)}, changed at #{inspect(source_updated_at)}")
        :ok

      :ok ->
        :ok

      error ->
        _ = Logger.error("Unable to update fees from file. Reason: #{inspect(error)}")
        error
    end
  end

  defp save_fees(fee_specs, last_updated_at) do
    true =
      :ets.insert(:fees_bucket, [
        {:updated_at, :os.system_time(:second)},
        {:fee_specs_source_updated_at, last_updated_at},
        {:fees, fee_specs}
      ])

    :ok
  end

  defp load_fees() do
    :ets.lookup_element(:fees_bucket, :fees, 2)
  end

  defp ensure_ets_init() do
    _ = if :undefined == :ets.info(:fees_bucket), do: :ets.new(:fees_bucket, [:set, :public, :named_table])

    true = :ets.insert(:fees_bucket, {:fee_specs_source_updated_at, 0})
    :ok
  end

  defp get_fee_adapter() do
    case Application.get_env(:omg_child_chain, :fee_adapter) do
      nil ->
        _ = Logger.error("Fee adapter not defined.")
        {:error, :fee_adapter_not_defined}

      fee_adapter ->
        {:ok, fee_adapter}
    end
  end
end
