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
  Serializes the response into expected result/data format.
  """

  @type response_result_t :: :success | :error

  @doc """
  Append result of operation to the response data forming standard api response structure
  """
  @spec serialize(any(), response_result_t()) :: %{result: response_result_t(), data: map()}
  def serialize(data, result)
  def serialize(data, :success), do: data |> clean_artifacts() |> to_response(:success)
  def serialize(data, :error), do: data |> to_response(:error)

  defp to_response(data, result), do: %{result: result, data: data}

  @doc """
  Decodes specified keys in map from hex to binary
  """
  @spec decode16(map(), list()) :: map()
  def decode16(data, keys) do
    keys
    |> Enum.filter(&Map.has_key?(data, &1))
    |> Enum.into(
      %{},
      fn key ->
        value = data[key]

        case is_binary(value) && Base.decode16(value, case: :mixed) do
          {:ok, newvalue} -> {key, newvalue}
          _ -> {key, value}
        end
      end
    )
    |> (&Map.merge(data, &1)).()
  end

  @doc """
  Removes or encodes fields in response that cannot be serialized to api response.
  By default, it:
   * encodes to hex all binary values
   * removes unloaded ecto associations values
   * removes metadata fields
  """
  @spec clean_artifacts(any()) :: any()
  def clean_artifacts(response)

  def clean_artifacts(list) when is_list(list) do
    list |> Enum.map(&clean_artifacts/1)
  end

  def clean_artifacts(map_or_struct) when is_map(map_or_struct) do
    map_or_struct
    |> to_map()
    |> Enum.filter(fn {_k, v} -> Ecto.assoc_loaded?(v) end)
    |> Enum.map(fn {k, v} -> {k, clean_artifacts(v)} end)
    |> Map.new()
  end

  def clean_artifacts(bin) when is_binary(bin), do: Base.encode16(bin)
  def clean_artifacts(value), do: value

  defp to_map(struct) do
    if(Map.has_key?(struct, :__struct__), do: struct |> Map.from_struct(), else: struct)
    |> Map.delete(:__meta__)
  end
end
