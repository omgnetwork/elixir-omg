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

defmodule OMG.ChildChain.HttpRPC.Client do
  @moduledoc """
  Provides functions to communicate with Child Chain API
  """

  alias OMG.ChildChain.Fees.JSONFeeParser
  alias OMG.Utils.HttpRPC.Adapter

  require Logger

  @type response_error_t() ::
          {:error, {:unsuccessful_response | :server_error, any()} | {:malformed_response, any() | {:error, :invalid}}}
  @type response_t() :: {:ok, %{required(atom()) => any()}} | response_error_t()

  @doc """
  Fetches latest fee prices from the fees feed
  """
  @spec all_fees(binary()) :: response_t()
  def all_fees(url) do
    "#{url}/fees"
    |> HTTPoison.get([{"content-type", "application/json"}])
    |> handle_response()
    |> parse_fee_response_body()
  end

  defp handle_response(http_response) do
    with {:ok, body} <- Adapter.get_unparsed_response_body(http_response),
         {:ok, response} <- Jason.decode(body),
         %{"success" => true, "data" => data} <- response do
      {:ok, data}
    else
      %{"success" => false, "data" => data} -> {:error, {:unsuccessful_response, data}}
      error -> error
    end
  end

  defp parse_fee_response_body({:ok, body}), do: JSONFeeParser.parse(body)
  defp parse_fee_response_body(error), do: error
end
