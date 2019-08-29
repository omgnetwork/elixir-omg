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
  def prepare_child do
    %{id: :vmstats_sup, start: {:vmstats_sup, :start_link, [__MODULE__, base_key()]}}
  end

  defp base_key, do: Application.get_env(:vmstats, :base_key)

  def collect(:counter, key, value), do: _ = Datadog.set(key, value, tags: ["application:#{get_application_mode()}"])

  def collect(:gauge, key, value), do: _ = Datadog.gauge(key, value, tags: ["application:#{get_application_mode()}"])

  def collect(:timing, key, value), do: _ = Datadog.timing(key, value, tags: ["application:#{get_application_mode()}"])

  # TODO yet another hack because of lacking releases
  # we store the tag in the process dictionary so that we don't have to go through the
  # difficult path of retrieving it later
  defp get_application_mode do
    case Process.get(:application_mode) do
      nil ->
        application = application()
        nil = Process.put(:application_mode, application)
        application

      application ->
        application
    end
  end

  defp application do
    is_child_chain_running =
      Enum.find(Application.started_applications(), fn
        {:omg_child_chain_rpc, _, _} -> true
        _ -> false
      end)

    if Code.ensure_loaded?(OMG.ChildChainRPC) and is_child_chain_running != nil do
      :child_chain
    else
      :watcher
    end
  end
end
