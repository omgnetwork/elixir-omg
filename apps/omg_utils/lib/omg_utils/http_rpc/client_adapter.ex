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

defmodule OMG.Utils.HttpRPC.ClientAdapter do
  @moduledoc """
  Provides utility functions to communicate with HTTP RPC APIs in Clients
  """

  alias OMG.Utils.HttpRPC.Encoding

  require Logger

  @doc """
    Makes HTTP POST request to the API
  """
  def rpc_post(body, path, url) do
    addr = "#{url}/#{path}"
    headers = [{"content-type", "application/json"}]

    with {:ok, body} <- Jason.encode(body),
         {:ok, %HTTPoison.Response{} = response} <- HTTPoison.post(addr, body, headers) do
      _ = Logger.debug("rpc post #{inspect(addr)} completed successfully")
      response
    else
      err ->
        _ = Logger.warn("rpc post #{inspect(addr)} failed with #{inspect(err)}")
        err
    end
  end

  @doc """
  Retrieves body from response structure. When response is successful
  the structure in body is known, so we can try to deserialize it.
  """
  def get_response_body(%HTTPoison.Response{status_code: 200, body: body}) do
    with {:ok, response} <- Jason.decode(body),
         %{"success" => true, "data" => data} <- response do
      {:ok, convert_keys_to_atoms(data)}
    else
      %{"success" => false, "data" => data} -> {:error, {:client_error, data}}
      match_err -> {:error, {:malformed_response, match_err}}
    end
  end

  def get_response_body(%HTTPoison.Response{body: error}),
    do: {:error, {:server_error, error}}

  def get_response_body(error), do: {:error, {:client_error, error}}

  @doc """
  Decodes specified keys in map from hex to binary
  """
  @spec decode16!(map(), list()) :: map()
  def decode16!(data, keys) do
    keys
    |> Enum.into(%{}, &decode16_for_key!(data, &1))
    |> (&Map.merge(data, &1)).()
  end

  defp decode16_for_key!(data, key) do
    case data[key] do
      value when is_binary(value) ->
        {key, decode16_value!(value)}

      value when is_list(value) ->
        bin_list =
          value
          |> Enum.map(&Encoding.from_hex/1)
          |> Enum.map(fn {:ok, bin} -> bin end)

        {key, bin_list}
    end
  end

  defp decode16_value!(value) do
    {:ok, bin} = Encoding.from_hex(value)
    bin
  end

  defp convert_keys_to_atoms(data) when is_list(data),
    do: Enum.map(data, &convert_keys_to_atoms/1)

  defp convert_keys_to_atoms(data) when is_map(data) do
    data
    |> Stream.map(fn {k, v} -> {String.to_existing_atom(k), convert_keys_to_atoms(v)} end)
    |> Map.new()
  end

  defp convert_keys_to_atoms(other_data), do: other_data
end
