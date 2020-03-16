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
defmodule OMG.Status.Metric.VmstatsSink do
  @moduledoc """
  Interface implementation.
  """
  alias OMG.Status.Metric.Datadog
  @type vm_stat :: {:vmstats_sup, :start_link, [any(), ...]}
  @behaviour :vmstats_sink

  @doc """
  Returns child_specs for the given metric setup, to be included e.g. in Supervisor's children.
  """
  @spec prepare_child() :: %{id: :vmstats_sup, start: vm_stat()}
  def prepare_child() do
    %{id: :vmstats_sup, start: {:vmstats_sup, :start_link, [__MODULE__, base_key()]}}
  end

  defp base_key(), do: Application.get_env(:vmstats, :base_key)
  # statix currently does not support `count` or `monotonic_count`, only increment and decrement
  # because of that, we're sending counters as gauges
  def collect(:counter, key, value), do: _ = Datadog.gauge(key, value)

  def collect(:gauge, key, value), do: _ = Datadog.gauge(key, value)

  def collect(:timing, key, value), do: _ = Datadog.timing(key, value)
end
