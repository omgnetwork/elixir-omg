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

defmodule LoadTest.ChildChain.Abi do
  alias ExPlasma.Encoding
  alias LoadTest.ChildChain.Abi.AbiEventSelector
  alias LoadTest.ChildChain.Abi.AbiFunctionSelector
  alias LoadTest.ChildChain.Abi.Fields

  alias OMG.Eth.RootChain.Fields

  def decode_log(log) do
    event_specs =
      Enum.reduce(AbiEventSelector.module_info(:exports), [], fn
        {:module_info, 0}, acc -> acc
        {function, 0}, acc -> [apply(AbiEventSelector, function, []) | acc]
        _, acc -> acc
      end)

    topics =
      Enum.map(log["topics"], fn
        nil -> nil
        topic -> Encoding.from_hex(topic)
      end)

    data = Encoding.from_hex(log["data"])

    {event_spec, data} =
      ABI.Event.find_and_decode(
        event_specs,
        Enum.at(topics, 0),
        Enum.at(topics, 1),
        Enum.at(topics, 2),
        Enum.at(topics, 3),
        data
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> Fields.rename(event_spec)
    |> common_parse_event(log)
  end
end
