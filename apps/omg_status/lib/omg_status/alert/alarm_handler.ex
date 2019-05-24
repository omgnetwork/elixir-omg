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

defmodule OMG.Status.Alert.AlarmHandler do
  @moduledoc """
    This is the SASL alarm handler process.
  """

  def install do
    previous_alarms = :alarm_handler.get_alarms()
    :ok = :gen_event.swap_handler(:alarm_handler, {:alarm_handler, :swap}, {__MODULE__, :ok})
    # migrates old alarms
    Enum.each(previous_alarms, &:alarm_handler.set_alarm(&1))
  end

  # -----------------------------------------------------------------
  # :gen_event handlers
  # -----------------------------------------------------------------
  def init(_args) do
    {:ok, %{alarms: []}}
  end

  def handle_call(:get_alarms, %{alarms: alarms} = state), do: {:ok, alarms, state}

  def handle_event({:set_alarm, new_alarm}, %{alarms: alarms} = state) do
    if Enum.any?(alarms, &(&1 == new_alarm)) do
      {:ok, state}
    else
      {:ok, %{alarms: [new_alarm | alarms]}}
    end
  end

  def handle_event({:clear_alarm, alarm_id}, %{alarms: alarms}) do
    new_alarms =
      alarms
      |> Enum.filter(&(elem(&1, 0) != alarm_id))
      |> Enum.filter(&(&1 != alarm_id))

    {:ok, %{alarms: new_alarms}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  def terminate(:swap, state), do: {__MODULE__, state}
  def terminate(_, _), do: :ok
end
