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

defmodule Status.Metric.Recorder do
  @moduledoc """
  A GenServer template for metrics recording.
  """
  @behaviour :vmstats_sink
  @type vm_stat :: {:vmstats_sup, :start_link, [any(), ...]}

  def collect(:counter, key, value) do
    key
    |> List.flatten()
    |> to_string()
    |> Appsignal.increment_counter(value, %{node: to_string(:erlang.node())})
  end

  def collect(:gauge, key, value) do
    key
    |> List.flatten()
    |> to_string()
    |> Appsignal.set_gauge(value, %{node: to_string(:erlang.node())})
  end

  def collect(:timing, key, value) do
    key
    |> List.flatten()
    |> to_string()
    |> Appsignal.set_gauge(value, %{node: to_string(:erlang.node())})
  end

  @doc """
  Returns child_specs for the given metric setup, to be included e.g. in Supervisor's children.
  """
  @spec prepare_child() :: %{id: :vmstats_sup, start: vm_stat()}
  def prepare_child do
    %{id: :vmstats_sup, start: {:vmstats_sup, :start_link, [__MODULE__, base_key()]}}
  end

  defp base_key, do: Application.get_env(:vmstats, :base_key)
end
