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
defmodule OMG.Utils.HttpRPC.Response do
  @moduledoc """
  Serializes the response into expected result/data format.
  """
  alias OMG.Utils.HttpRPC.Encoding
  @sha String.replace(elem(System.cmd("git", ["rev-parse", "--short=7", "HEAD"]), 0), "\n", "")

  @type response_t :: %{version: binary(), success: boolean(), data: map()}

  def serialize_page(data, data_paging) do
    data
    |> serialize()
    |> Map.put(:data_paging, data_paging)
  end

  @doc """
  Append result of operation to the response data forming standard api response structure
  """
  @spec serialize(any()) :: response_t()
  def serialize(%{object: :error} = error) do
    to_response(error, :error)
    |> add_version()
    |> add_service_name()
  end

  def serialize(data) do
    data
    |> sanitize()
    |> to_response(:success)
    |> add_version()
    |> add_service_name()
  end

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
    map_or_struct
    |> to_map()
    |> do_filter()
    |> sanitize_map()
  end

  def sanitize(bin) when is_binary(bin), do: Encoding.to_hex(bin)
  def sanitize({:skip_hex_encode, bin}), do: bin
  def sanitize({{key, value}, _}), do: Map.put_new(%{}, key, value)
  def sanitize({key, value}), do: Map.put_new(%{}, key, value)
  def sanitize(value), do: value

  defp do_filter(map_or_struct) do
    if :code.is_loaded(Ecto) do
      Enum.filter(map_or_struct, fn
        {_, %{__struct__: Ecto.Association.NotLoaded}} -> false
        _ -> true
      end)
      |> Map.new()
    else
      map_or_struct
    end
  end

  # Allows to skip sanitize on specifies keys provided in list in key :skip_hex_encode
  defp sanitize_map(map) do
    {skip_keys, map} = Map.pop(map, :skip_hex_encode, [])
    skip_keys = MapSet.new(skip_keys)

    map
    |> Enum.map(fn {k, v} ->
      case MapSet.member?(skip_keys, k) do
        true -> {k, v}
        false -> {k, sanitize(v)}
      end
    end)
    |> Map.new()
  end

  defp to_map(struct), do: Map.drop(struct, [:__struct__, :__meta__])

  defp to_response(data, result),
    do: %{
      success: result == :success,
      data: data
    }

  # not the most beatuful way of doing this but
  # because our "response serializer" is in utils there's no other way
  defp add_version(response) do
    vsn =
      case :code.is_loaded(OMG.ChildChainRPC) do
        {:file, _} ->
          {:ok, vsn} = :application.get_key(:omg_child_chain_rpc, :vsn)

          vsn

        _ ->
          {:ok, vsn} = :application.get_key(:omg_watcher_rpc, :vsn)

          vsn
      end

    Map.merge(response, %{version: List.to_string(vsn) <> "+" <> @sha})
  end

  # Not the most "beautiful way", but I'm just referencing
  # how they're injecting the version
  defp add_service_name(response) do
    service_name = service_name()
    # Inject it into the response code
    Map.merge(response, %{service_name: service_name})
  end

  defp service_name do
    case :code.is_loaded(OMG.ChildChainRPC) do
      {:file, _} ->
        "child_chain"

      _ ->
        "watcher"
    end
  end
end
