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
defmodule OMG.Utils.HttpRPC.Response do
  @moduledoc """
  Serializes the response into expected result/data format.

  TODO: Intentionally we want to have single Phx app exposing both APIs, until then please keep this file similar
  to the corresponding Watcher's one to make merge simpler.
  """
  alias OMG.Utils.HttpRPC.Encoding
  @type response_t :: %{version: binary(), success: boolean(), data: map()}

  @doc """
  Append result of operation to the response data forming standard api response structure
  """
  @spec serialize(any()) :: response_t()
  def serialize(%{object: :error} = error), do: to_response(error, :error)
  def serialize(data), do: to_response(data, :success)

  @doc """
  Removes or encodes fields in response that cannot be serialized to api response.
  By default, it:
   * encodes to hex all binary values
   * removes metadata fields
  Provides standard data structure for API response
  """
  @spec sanitize(any()) :: any()
  def sanitize(response)

  def sanitize(list) when is_list(list) do
    list |> Enum.map(&sanitize/1)
  end

  def sanitize(map_or_struct) when is_map(map_or_struct) do
    if Code.ensure_loaded?(Ecto) do
      map_or_struct
      |> to_map()
      |> Enum.filter(fn {_k, v} -> Ecto.assoc_loaded?(v) end)
      |> Enum.map(fn {k, v} -> {k, sanitize(v)} end)
      |> Map.new()
    else
      map_or_struct
      |> to_map()
      |> Enum.map(fn {k, v} -> {k, sanitize(v)} end)
      |> Map.new()
    end
  end

  def sanitize(bin) when is_binary(bin), do: Encoding.to_hex(bin)
  def sanitize({:skip_hex_encode, bin}), do: bin
  def sanitize(value), do: value

  defp to_map(struct), do: Map.drop(struct, [:__struct__, :__meta__])

  defp to_response(data, result),
    do: %{
      version: "1.0",
      success: result == :success,
      data: data
    }
end
