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

defmodule OMG.ChildChain.DatadogEvent.Encode do
  @moduledoc """
  Iterates the input and hex encodes binaries
  """

  def make_it_readable!(event) when is_map(event) do
    compactor = fn {k, v}, acc ->
      cond do
        is_map(v) and Enum.empty?(v) -> acc
        is_list(v) -> Map.put_new(acc, k, make_it_readable!(v))
        is_map(v) -> Map.put_new(acc, k, make_it_readable!(v))
        k == :event_signature -> Map.put_new(acc, k, v)
        is_binary(v) -> Map.put_new(acc, k, "0x" <> Base.encode16(v, case: :lower))
        true -> Map.put_new(acc, k, v)
      end
    end

    Enum.reduce(event, %{}, compactor)
  end

  def make_it_readable!(event) when is_list(event) do
    compactor = fn v, acc ->
      cond do
        is_map(v) and Enum.empty?(v) -> acc
        is_integer(v) -> [v | acc]
        is_map(v) -> [make_it_readable!(v) | acc]
        is_binary(v) -> ["0x" <> Base.encode16(v, case: :lower) | acc]
        true -> [v | acc]
      end
    end

    Enum.reduce(event, [], compactor)
  end
end
