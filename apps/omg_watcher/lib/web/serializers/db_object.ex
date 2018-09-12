# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.Web.Serializer.DBObject do
  @moduledoc """

  """

  #FIXME: @docs
  @doc """

  """
  def clean(value) do
    clean_value(value)
  end

  defp clean_value(list) when is_list(list) do
    list |> Enum.map(&clean_value/1)
  end

  defp clean_value(map_or_struct) when is_map(map_or_struct) do
    map_or_struct
    |> to_map()
    |> Enum.filter(fn {_k,v} -> Ecto.assoc_loaded?(v) end)
    |> Enum.map(fn {k, v} -> {k, clean_value(v)} end)
    |> Map.new()
  end

  defp clean_value(bin) when is_binary(bin), do: Base.encode16(bin)
  defp clean_value(value), do: value

  defp to_map(struct) do
    (if Map.has_key?(struct, :__struct__),
      do: struct |> Map.from_struct(), else: struct
    )
    |> Map.delete(:__meta__)
  end
end
