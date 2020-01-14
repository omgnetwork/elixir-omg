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

defmodule OMG.ChildChain.BlockQueue.Measure do
  @moduledoc """
  Counting business metrics sent to Datadog.
  We don't want to pattern match on :ok to Datadog because the connection
  towards the statsd client can be intermittent and sending would be unsuccessful and that
  would trigger the removal of telemetry handler. But because we have monitors in place,
  that eventually recover the connection to Statsd handlers wouldn't exist anymore and metrics
  wouldn't be published.
  """
  alias OMG.Status.Metric.Datadog
  import OMG.Status.Metric.Event, only: [name: 2]

  def handle_event([:process, OMG.ChildChain.BlockQueue], _, state, _config) do
    value =
      self()
      |> Process.info(:message_queue_len)
      |> elem(1)

    _ = Datadog.gauge(name(state.service_name, :message_queue_len), value)
  end
end
