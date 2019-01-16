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

defmodule OMG.Watcher.Web.Serializer.Response do
  @moduledoc """
  Provides functionality to process response to serializable form.
  """

  @doc """
  Removes or encodes fields in response that cannot be serialized to api response.
  By default, it:
   * encodes to hex all binary values
   * removes unloaded ecto associations values
   * removes metadata fields
   * passes binary data unchanged when wrapped with tuple `{:skip_hex_encode, data}`
  """
  @spec sanitize(any()) :: any()
  def sanitize(response)

  def sanitize(list) when is_list(list) do
    list |> Enum.map(&sanitize/1)
  end

  def sanitize(map_or_struct) when is_map(map_or_struct) do
    map_or_struct
    |> to_map()
    |> Enum.filter(fn {_k, v} -> Ecto.assoc_loaded?(v) end)
    |> Enum.map(fn {k, v} -> {k, sanitize(v)} end)
    |> Map.new()
  end

  def sanitize(bin) when is_binary(bin), do: OMG.RPC.Web.Encoding.to_hex(bin)
  def sanitize({:skip_hex_encode, bin}), do: bin
  def sanitize(value), do: value

  defp to_map(struct) do
    if(Map.has_key?(struct, :__struct__), do: struct |> Map.from_struct(), else: struct)
    |> Map.delete(:__meta__)
  end
end
