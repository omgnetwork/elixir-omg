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

defmodule OMG.Status.DatadogEvent.AlarmHandler do
  @moduledoc """
     Is notified of raised and cleared alarms and casts them to AlarmConsumer process.
  """

  require Logger

  def init([reporter]) do
    {:ok, reporter}
  end

  def handle_call(_request, reporter), do: {:ok, :ok, reporter}

  def handle_event({:set_alarm, _alarm_details} = alarm, reporter) do
    :ok = GenServer.cast(reporter, alarm)
    {:ok, reporter}
  end

  def handle_event({:clear_alarm, _alarm_details} = alarm, reporter) do
    :ok = GenServer.cast(reporter, alarm)
    {:ok, reporter}
  end

  def handle_event(event, reporter) do
    _ = Logger.info("#{__MODULE__} got event: #{inspect(event)}. Ignoring.")
    {:ok, reporter}
  end
end
