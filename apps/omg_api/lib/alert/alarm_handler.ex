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

defmodule OMG.API.Alert.AlarmHandler do
  @moduledoc """
  Handler for OMG API app.
  """

  def install, do: :alarm_handler.add_alarm_handler(__MODULE__)

  @callback ethereum_client_connection_issue(node(), module()) :: {atom(), map()}

  # subscribing to alarms of type
  def alarm_types, do: [:ethereum_client_connection]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, %{alarms: []}}
  end

  def handle_call(:get_alarms, %{alarms: alarms} = state), do: {:ok, alarms, state}

  def handle_event({:set_alarm, new_alarm}, %{alarms: alarms} = state) do
    # was the alarm raised already and is this our type of alarm?
    case {Enum.any?(alarms, &(&1 == new_alarm)), Enum.member?(alarm_types(), elem(new_alarm, 0))} do
      {true, _} ->
        {:ok, state}

      {false, true} ->
        # the alarm has not been raised before and we're subscribed
        {:ok, %{alarms: [new_alarm | alarms]}}

      {_, _} ->
        {:ok, state}
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

  def terminate(_, _), do: :ok
end
