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
defmodule OMG.Eth.RootChain.Event do
  @moduledoc """
  Parse signatures from Event definitions so that we're able to create eth_getLogs topics
  """
  alias OMG.Eth.RootChain.AbiEventSelector

  @spec get_events(list(atom())) :: list(binary())
  def get_events(wanted_events) do
    events = events()

    wanted_events
    |> Enum.reduce([], fn wanted_event_name, acc ->
      get_event(events, wanted_event_name, acc)
    end)
    |> Enum.reverse()
  end

  # pull all exported functions out the AbiEventSelector module
  # and create an event signature
  # function_name(arguments)
  @spec events() :: list({atom(), binary()})
  defp events() do
    Enum.reduce(AbiEventSelector.module_info(:exports), [], fn
      {:module_info, 0}, acc -> acc
      {function, 0}, acc -> [{function, describe_event(apply(AbiEventSelector, function, []))} | acc]
      _, acc -> acc
    end)
  end

  defp describe_event(selector) do
    "#{selector.function}(" <> build_types_string(selector.types) <> ")"
  end

  defp build_types_string(types), do: build_types_string(types, "")
  defp build_types_string([], string), do: string

  defp build_types_string([{type, size} | [] = types], string) do
    build_types_string(types, string <> "#{type}" <> "#{size}")
  end

  defp build_types_string([{type, size} | types], string) do
    build_types_string(types, string <> "#{type}" <> "#{size}" <> ",")
  end

  defp build_types_string([type | [] = types], string) do
    build_types_string(types, string <> "#{type}")
  end

  defp build_types_string([type | types], string) do
    build_types_string(types, string <> "#{type}" <> ",")
  end

  def get_event(events, wanted_event_name, acc) do
    case Enum.find(events, fn {function_name, _signature} -> function_name == wanted_event_name end) do
      nil -> acc
      {_, signature} -> [signature | acc]
    end
  end
end
