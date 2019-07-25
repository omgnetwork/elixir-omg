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

defmodule OMG.Watcher.Eventer.Measure do
  @moduledoc """
  Counting business metrics sent to Datadog
  """

  import OMG.Status.Metric.Event, only: [name: 1]
  alias OMG.Status.Metric.Datadog

  @supported_events [[:process, OMG.Watcher.Eventer]]
  def supported_events, do: @supported_events

  def handle_event([:process, OMG.Watcher.Eventer], _state, _metadata, _config) do
    value =
      self()
      |> Process.info(:message_queue_len)
      |> elem(1)

    :ok = Datadog.gauge(name(:eventer_message_queue_len), value)
  end
end
