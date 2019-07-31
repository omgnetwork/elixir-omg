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

defmodule OMG.ChildChain.FeeParser do
  @moduledoc """
  Transaction's fee validation functions
  """

  require Logger

  @doc """
  Parses and validates json encoded fee specifications file

  Parses provided json string to token-fee map and returns the map together with possible parsing errors
  """
  @spec parse_file_content(binary()) :: {:ok, OMG.Fees.fee_t()} | {:error, list({:error, atom()})}
  def parse_file_content(file_content) do
    with {:ok, json} <- Jason.decode(file_content) do
      {errors, token_fee_map, _} =
        json
        |> Enum.map(&parse_fee_spec/1)
        |> Enum.reduce({[], %{}, 1}, &spec_reducer/2)

      errors
      |> Enum.reverse()
      |> (&{&1, token_fee_map}).()
      |> handle_parser_output()
    end
  end

  defp parse_fee_spec(%{"flat_fee" => fee, "token" => token}) do
    # defensive code against user input
    with {:ok, fee} <- validate_fee(fee),
         {:ok, addr} <- decode_address(token) do
      %{token: addr, flat_fee: fee}
    end
  end

  defp parse_fee_spec(_), do: {:error, :invalid_fee_spec}

  defp validate_fee(fee) when is_integer(fee) and fee >= 0, do: {:ok, fee}
  defp validate_fee(_fee), do: {:error, :invalid_fee}

  defp spec_reducer({:error, _} = error, {errors, token_fee_map, spec_index}),
    # most errors can be detected parsing particular record
    do: {[{error, spec_index} | errors], token_fee_map, spec_index + 1}

  defp spec_reducer(%{token: token, flat_fee: fee}, {errors, token_fee_map, spec_index}) do
    # checks whether token was specified before
    if Map.has_key?(token_fee_map, token),
      do: {[{{:error, :duplicate_token}, spec_index} | errors], token_fee_map, spec_index + 1},
      else: {errors, Map.put(token_fee_map, token, fee), spec_index + 1}
  end

  defp handle_parser_output({[], fee_specs}) do
    _ = Logger.debug("Parsing fee specification file completes successfully.")
    {:ok, fee_specs}
  end

  defp handle_parser_output({[{_error, _index} | _] = errors, _fee_specs}) do
    _ = Logger.warn("Parsing fee specification file fails with errors:")

    Enum.each(errors, fn {{:error, reason}, index} ->
      _ = Logger.warn(" * ##{inspect(index)} fee spec parser failed with error: #{inspect(reason)}")
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
