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

defmodule OMG.Status.Alert.AlarmHandler do
  @moduledoc """
    This is the SASL alarm handler process.
  """
  alias OMG.Status.Alert.Alarm
  @table_name :alarms

  def install() do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true ->
        :ok

      false ->
        previous_alarms = :alarm_handler.get_alarms()
        :ok = :gen_event.swap_handler(:alarm_handler, {:alarm_handler, :swap}, {__MODULE__, :ok})
        # migrates old alarms
        Enum.each(previous_alarms, &:alarm_handler.set_alarm(&1))
    end
  end

  def table_name(), do: @table_name

  # -----------------------------------------------------------------
  # :gen_event handlers
  # -----------------------------------------------------------------
  def init(_args) do
    table_setup()

    for n <- Alarm.alarm_types(), do: write_clear(n)
    {:ok, %{alarms: []}}
  end

  def handle_call(:get_alarms, %{alarms: alarms} = state), do: {:ok, alarms, state}

  def handle_event({:set_alarm, new_alarm}, %{alarms: alarms} = state) do
    # was the alarm raised already and is this our type of alarm?

    case Enum.any?(alarms, &(&1 == new_alarm)) do
      true ->
        {:ok, state}

      false ->
        # the alarm has not been raised before and we're subscribed
        _ = write_raise(new_alarm)
        {:ok, %{alarms: [new_alarm | alarms]}}
    end
  end

  def handle_event({:clear_alarm, alarm_id}, %{alarms: alarms}) do
    new_alarms =
      alarms
      |> Enum.filter(&(elem(&1, 0) != alarm_id))
      |> Enum.filter(&(&1 != alarm_id))

    _ = write_clear(alarm_id)
    {:ok, %{alarms: new_alarms}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  def terminate(:swap, state), do: {__MODULE__, state}
  def terminate(_, _), do: :ok

  defp table_setup() do
    _ = if :undefined == :ets.info(@table_name), do: @table_name = :ets.new(@table_name, table_settings())
  end

  defp table_settings(), do: [:named_table, :set, :protected, read_concurrency: true]

  defp write_raise(alarm) when is_tuple(alarm), do: write_raise(elem(alarm, 0))
  defp write_raise(key) when is_atom(key), do: :ets.update_counter(@table_name, key, {2, 1, 1, 1}, {key, 0})

  defp write_clear(alarm) when is_tuple(alarm), do: write_clear(elem(alarm, 0))
  defp write_clear(key) when is_atom(key), do: :ets.update_counter(@table_name, key, {2, -1, 0, 0}, {key, 1})
end
