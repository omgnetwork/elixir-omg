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

defmodule OMG.Eth.Metric.Ethereumex do
  alias OMG.Status.Metric.Datadog
  def supported_events(), do: [:ethereumex]

  def handle_event([:ethereumex], %{counter: counter}, %{method_name: method_name} = _metadata, _config) do
    Datadog.increment(method_name, counter)
  end
end
