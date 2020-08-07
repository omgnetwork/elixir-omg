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
defmodule OMG.Eth.Tenderly.Client do
  @moduledoc """
  Tenderly HTTP API client
  """

  @default_timeout 20_000
  @default_recv_timeout 20_000

  defmodule SimulateRequest do
    @moduledoc """
    Wrapper for arguments used in Tenderly simulate API call
    """
    @enforce_keys [:from, :to, :input, :value, :block_number, :transaction_index, :gas]
    defstruct [:from, :to, :input, :value, :block_number, :transaction_index, :gas]

    @type t() :: %__MODULE__{
            from: binary(),
            to: binary(),
            input: binary(),
            value: non_neg_integer(),
            block_number: non_neg_integer(),
            transaction_index: non_neg_integer(),
            gas: pos_integer()
          }
  end

  @doc """
  Calls simulate transaction endpoint
  """
  @spec simulate_transaction(SimulateRequest.t()) :: {:ok, map()} | {:error, atom()}
  def simulate_transaction(simulate_request) do
    {url, access_key} = get_url_and_token()
    body = get_simulate_request_body(simulate_request)
    options = get_tenderly_call_options()

    url
    |> HTTPoison.post(
      body,
      [{"Content-Type", "application/json"}, {"x-access-key", access_key}, {"Connection", "keep-alive"}],
      options
    )
    |> handle_response()
  end

  defp get_url_and_token() do
    config = get_config()
    tenderly_project_url = Keyword.fetch!(config, :tenderly_project_url)
    access_key = Keyword.fetch!(config, :access_key)
    url = "#{tenderly_project_url}/simulate"
    {url, access_key}
  end

  defp get_simulate_request_body(simulate_request) do
    config = get_config()
    network_id = Keyword.fetch!(config, :network_id)

    Jason.encode!(%{
      "network_id" => network_id,
      "from" => simulate_request.from,
      "to" => simulate_request.to,
      "input" => simulate_request.input,
      "value" => simulate_request.value,
      "block_number" => simulate_request.block_number,
      "transaction_index" => simulate_request.transaction_index,
      "gas" => simulate_request.gas
    })
  end

  defp get_tenderly_call_options() do
    config = get_config()
    timeout = Keyword.get(config, :timeout, @default_timeout)
    recv_timeout = Keyword.get(config, :recv_timeout, @default_recv_timeout)
    [timeout: timeout, recv_timeout: recv_timeout]
  end

  defp get_config() do
    Application.fetch_env!(:omg_eth, __MODULE__)
  end

  defp handle_response({:error, %HTTPoison.Error{reason: reason}}) do
    {:error, reason}
  end

  defp handle_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    {:ok, Jason.decode!(body)}
  end

  defp handle_response({:ok, _}) do
    {:error, :unexpected_response_from_tenderly}
  end
end
