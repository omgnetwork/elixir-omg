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

  @spec serialize(map(), response_result_t()) :: %{result: response_result_t(), data: map()}
  def serialize(data, result) do
    %{
      result: result,
      data: data
    }
  end

  @spec encode16(list(map()) | map(), list(String.t() | atom())) :: map()
  def encode16(list, fields) when is_list(list) do
    list |> Enum.map(&encode16(&1, fields))
  end

  def encode16(map, fields) when is_map(map) do
    update_values(
      map,
      fields,
      fn {k, v} -> {k, Base.encode16(v)} end
    )
  end

  @spec decode16(list(map()) | map(), list(String.t() | atom())) :: map()
  def decode16(list, fields) when is_list(list) do
    list |> Enum.map(&decode16(&1, fields))
  end

  def decode16(map, fields) when is_map(map) do
    update_values(
      map,
      fields,
      fn {k, v} ->
        {:ok, decoded_v} = Base.decode16(v, case: :mixed)
        {k, decoded_v}
      end
    )
  end

  @spec update_values(map(), list(String.t()), fun()) :: map()
  defp update_values(map, fields, fun) when is_map(map) do
    updated_fields =
      map
      |> Enum.filter(fn {key, _value} -> Enum.member?(fields, key) end)
      |> Enum.into(%{}, &fun.(&1))

    map
    |> Map.merge(updated_fields)
  end
end
