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
defmodule OMG.ChildChain.Fees.JSONFeeParser do
  @moduledoc """
  Transaction's fee validation functions
  """
  require Logger

  alias OMG.ChildChain.Fees.JSONSingleSpecParser

  @type parsing_error() ::
          JSONSingleSpecParser.parsing_error()
          # There is a duplicated token for the same tx type
          | :duplicate_token
          # the format of the json is invalid (ie: it's an array)
          | :invalid_json_format
          # the tx type can't be parsed to an integer
          | :invalid_tx_type

  @doc """
  Parses and validates json encoded fee specifications response
  Parses provided json string to token-fee map and returns the map together with possible parsing errors
  """
  @spec parse(binary() | map() | list()) ::
          {:ok, OMG.Fees.full_fee_t()}
          | {:error, list({:error, parsing_error(), any(), non_neg_integer() | nil})}
  def parse(file_content) when is_binary(file_content) do
    with {:ok, json} <- Jason.decode(file_content), do: parse(json)
  end

  def parse(json) when is_map(json) do
    {errors, fee_specs} = Enum.reduce(json, {[], %{}}, &reduce_json/2)

    errors
    |> Enum.reverse()
    |> (&{&1, fee_specs}).()
    |> handle_parser_output()
  end

  defp reduce_json({tx_type, fee_spec}, {all_errors, fee_specs}) do
    tx_type
    |> Integer.parse()
    |> parse_for_type(fee_spec)
    |> handle_type_parsing_output(tx_type, all_errors, fee_specs)
  end

  defp reduce_json(_, {all_errors, fee_specs}) do
    {[{:error, :invalid_json_format, nil, nil} | all_errors], fee_specs}
  end

  defp parse_for_type({tx_type, ""}, fee_spec) do
    fee_spec
    |> Enum.map(&JSONSingleSpecParser.parse/1)
    |> Enum.reduce({[], %{}, 1, tx_type}, &spec_reducer/2)
  end

  defp parse_for_type(_, _), do: {:error, :invalid_tx_type}

  defp handle_type_parsing_output({:error, :invalid_tx_type} = error, tx_type, all_errors, fee_specs) do
    e =
      error
      |> Tuple.append(tx_type)
      |> Tuple.append(0)

    {[e | all_errors], fee_specs}
  end

  defp handle_type_parsing_output({errors, token_fee_map, _, tx_type}, _, all_errors, fee_specs) do
    {errors ++ all_errors, Map.put(fee_specs, tx_type, token_fee_map)}
  end

  defp spec_reducer({:error, reason}, {errors, token_fee_map, spec_index, tx_type}),
    # most errors can be detected parsing particular record
    do: {[{:error, reason, tx_type, spec_index} | errors], token_fee_map, spec_index + 1, tx_type}

  defp spec_reducer(
         {:ok,
          %{
            token: token
          } = token_fee},
         {errors, token_fee_map, spec_index, tx_type}
       ) do
    token_fee = Map.drop(token_fee, [:token])
    # checks whether token was specified before
    if Map.has_key?(token_fee_map, token),
      do: {[{:error, :duplicate_token, tx_type, spec_index} | errors], token_fee_map, spec_index + 1, tx_type},
      else: {errors, Map.put(token_fee_map, token, token_fee), spec_index + 1, tx_type}
  end

  defp handle_parser_output({[], fee_specs}) do
    _ = Logger.info("Parsing fee specification file completes successfully.")
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
end
