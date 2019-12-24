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
defmodule OMG.ChildChain.Fees.FeeParser do
  @moduledoc """
  Transaction's fee validation functions
  """
  require Logger

  # the format of the json is invalid (ie: it's an array)
  @type parsing_error() ::
          :invalid_json_format
          # the tx type can't be parsed to an integer
          | :invalid_tx_type
          # the fee spec for a specific type/token is missing keys
          | :invalid_fee_spec
          # the fee amount is invalid (must be >= 0)
          | :invalid_fee
          # the subunit to unit is invalid (must be > 0)
          | :invalid_subunit_to_unit
          # the pegged amount is invalid (must be > 0)
          | :invalid_pegged_amount
          # the pegged currency is invalid (must be > 0)
          | :invalid_pegged_currency
          # the pegged subunit to unit is invalid (must be > 0)
          | :invalid_pegged_subunit_to_unit
          # the updated at date is invalid (wrong date format)
          | :invalid_timestamp
          # the token address is invalid (must be a valid Ethereum address)
          | :bad_address_encoding
          # There is a duplicated token for the same tx type
          | :duplicate_token

  @doc """
  Parses and validates json encoded fee specifications file
  Parses provided json string to token-fee map and returns the map together with possible parsing errors
  """
  @spec parse(binary()) ::
          {:ok, OMG.Fees.full_fee_t()} | {:error, list({:error, parsing_error(), any(), non_neg_integer() | nil})}
  def parse(file_content) do
    with {:ok, json} <- Jason.decode(file_content) do
      {errors, fee_specs} = Enum.reduce(json, {[], %{}}, &reduce_json/2)

      errors
      |> Enum.reverse()
      |> (&{&1, fee_specs}).()
      |> handle_parser_output()
    end
  end

  defp reduce_json({tx_type, fee_spec}, {all_errors, fee_specs}) do
    tx_type
    |> Integer.parse()
    |> parse_for_type(fee_spec)
    |> handle_type_parsing_output(tx_type, all_errors, fee_specs)
  end

  defp reduce_json(_, {all_errors, fee_specs}) do
    {[{:error, :invalid_json_format, nil, nil}] ++ all_errors, fee_specs}
  end

  defp parse_for_type({tx_type, ""}, fee_spec) do
    fee_spec
    |> Enum.map(&parse_single_spec/1)
    |> Enum.reduce({[], %{}, 1, tx_type}, &spec_reducer/2)
  end

  defp parse_for_type(_, _), do: {:error, :invalid_tx_type}

  defp handle_type_parsing_output({:error, :invalid_tx_type} = error, tx_type, all_errors, fee_specs) do
    e =
      error
      |> Tuple.append(tx_type)
      |> Tuple.append(0)

    {[e] ++ all_errors, fee_specs}
  end

  defp handle_type_parsing_output({errors, token_fee_map, _, tx_type}, _, all_errors, fee_specs) do
    {errors ++ all_errors, Map.put(fee_specs, tx_type, token_fee_map)}
  end

  defp parse_single_spec(%{
         "amount" => fee,
         "token" => token,
         "subunit_to_unit" => subunit_to_unit,
         "pegged_amount" => pegged_amount,
         "pegged_currency" => pegged_currency,
         "pegged_subunit_to_unit" => pegged_subunit_to_unit,
         "updated_at" => updated_at
       }) do
    # defensive code against user input
    with {:ok, fee} <- validate_fee_amount(fee, :invalid_fee),
         {:ok, addr} <- decode_address(token),
         {:ok, subunit_to_unit} <- validate_positive_amount(subunit_to_unit, :invalid_subunit_to_unit),
         {:ok, pegged_amount} <- validate_positive_amount(pegged_amount, :invalid_pegged_amount),
         {:ok, pegged_currency} <- validate_pegged_currency(pegged_currency),
         {:ok, pegged_subunit_to_unit} <-
           validate_positive_amount(pegged_subunit_to_unit, :invalid_pegged_subunit_to_unit),
         {:ok, updated_at} <- validate_updated_at(updated_at) do
      %{
        token: addr,
        amount: fee,
        subunit_to_unit: subunit_to_unit,
        pegged_amount: pegged_amount,
        pegged_currency: pegged_currency,
        pegged_subunit_to_unit: pegged_subunit_to_unit,
        updated_at: updated_at
      }
    end
  end

  defp parse_single_spec(_), do: {:error, :invalid_fee_spec}
  defp validate_fee_amount(amount, _error) when is_integer(amount) and amount >= 0, do: {:ok, amount}
  defp validate_fee_amount(_amount, error), do: {:error, error}
  defp validate_positive_amount(amount, _error) when is_integer(amount) and amount > 0, do: {:ok, amount}
  defp validate_positive_amount(_amount, error), do: {:error, error}
  defp validate_pegged_currency(pegged_currency) when is_binary(pegged_currency), do: {:ok, pegged_currency}
  defp validate_pegged_currency(_pegged_currency), do: {:error, :invalid_pegged_currency}

  defp validate_updated_at(updated_at) do
    case DateTime.from_iso8601(updated_at) do
      {:ok, %DateTime{} = date_time, _} -> {:ok, date_time}
      _ -> {:error, :invalid_timestamp}
    end
  end

  defp spec_reducer({:error, reason}, {errors, token_fee_map, spec_index, tx_type}),
    # most errors can be detected parsing particular record
    do: {[{:error, reason, tx_type, spec_index} | errors], token_fee_map, spec_index + 1, tx_type}

  defp spec_reducer(
         %{
           token: token
         } = token_fee,
         {errors, token_fee_map, spec_index, tx_type}
       ) do
    token_fee = Map.drop(token_fee, [:token])
    # checks whether token was specified before
    if Map.has_key?(token_fee_map, token),
      do: {[{:error, :duplicate_token, tx_type, spec_index} | errors], token_fee_map, spec_index + 1, tx_type},
      else: {errors, Map.put(token_fee_map, token, token_fee), spec_index + 1, tx_type}
  end

  defp handle_parser_output({[], fee_specs}) do
    _ = Logger.debug("Parsing fee specification file completes successfully.")
    {:ok, fee_specs}
  end

  defp handle_parser_output({[{:error, _error, _tx_type, _index} | _] = errors, _fee_specs}) do
    _ = Logger.warn("Parsing fee specification file fails with errors:")

    Enum.each(errors, fn {:error, reason, tx_type, index} ->
      _ =
        Logger.warn(
          " * ##{inspect(index)} for transaction type ##{inspect(tx_type)} fee spec parser failed with error: #{
            inspect(reason)
          }"
        )
    end)

    {:error, errors}
  end

  defp decode_address("0x" <> data), do: decode_address(data)

  defp decode_address(data) do
    case Base.decode16(data, case: :mixed) do
      {:ok, address} when byte_size(address) == 20 ->
        {:ok, address}

      _ ->
        {:error, :bad_address_encoding}
    end
  end
end
