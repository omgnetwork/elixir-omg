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

defmodule OMG.API.FeeChecker.Core do
  @moduledoc """
  Transaction's fee validation functions
  """

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.State.Transaction.Recovered
  alias Poison

  @type fee_spec_t() :: %{token: Crypto.address_t(), flat_fee: non_neg_integer}
  @type token_fee_t() :: %{Crypto.address_t() => non_neg_integer}

  @doc """
  Calculates fee from transaction and checks whether token is allowed and flat fee limits are met
  """
  @spec transaction_fees(Recovered.t(), token_fee_t()) :: {:ok, token_fee_t()} | {:error, :token_not_allowed}
  def transaction_fees(
        %Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction{cur12: cur12}}},
        token_fees
      ) do
    currencies = [cur12]
    tx_fees = Map.take(token_fees, currencies)

    if Enum.all?(currencies, &Map.has_key?(tx_fees, &1)),
      do: {:ok, tx_fees},
      else: {:error, :token_not_allowed}
  end

  @doc """
  Parses provided json string to token-fee map and returns the map together with possible parsing errors
  """
  @spec parse_file_content(binary()) :: {list({:error, atom()}), token_fee_t()}
  def parse_file_content(file_content) do
    {:ok, json} = Poison.decode(file_content)

    {errors, token_fee_map, _} =
      json
      |> Enum.map(&parse_fee_spec/1)
      |> Enum.reduce({[], %{}, 1}, &spec_reducer/2)

    {Enum.reverse(errors), token_fee_map}
  end

  defp parse_fee_spec(%{"flat_fee" => fee, "token" => token}) do
    # defensive code against user input
    with {:ok, fee} <- validate_fee(fee),
         {:ok, addr} <- Crypto.decode_address(token) do
      %{token: addr, flat_fee: fee}
    end
  end

  defp parse_fee_spec(_), do: {:error, :invalid_fee_spec}

  defp validate_fee(fee) when is_integer(fee) and fee >= 0, do: {:ok, fee}
  defp validate_fee(_fee), do: {:error, :invalid_fee}

  defp spec_reducer(fee_spec, {errors, token_fee_map, spec_index}) do
    case fee_spec do
      # most errors can be detected parsing particular record
      {:error, _} = error ->
        {[{error, spec_index} | errors], token_fee_map, spec_index + 1}

      # checks whether token was specified before
      %{token: token, flat_fee: fee} ->
        if Map.has_key?(token_fee_map, token),
          do: {[{{:error, :duplicate_token}, spec_index} | errors], token_fee_map, spec_index + 1},
          else: {errors, Map.put(token_fee_map, token, fee), spec_index + 1}
    end
  end
end
