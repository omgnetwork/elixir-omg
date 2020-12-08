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

defmodule Eip55Normalizer do
  @moduledoc """
  Normalizes contract addresses.
  """

  @spec run() :: :ok | no_return
  def run() do
    path =
      case System.argv() do
        [path] -> path
        _ -> raise("wrong path format")
      end

    path
    |> parse_env_file()
    |> write_file(path)
  end

  defp parse_env_file(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> List.flatten()
    |> Enum.reduce(%{}, fn line, acc ->
      [key, value] = String.split(line, "=")

      new_value =
        case {key, value} do
          {"TXHASH_CONTRACT", value} ->
            value

          {_, ""} ->
            ""

          _ ->
            {:ok, eip55_value} = EIP55.encode(value)
            eip55_value
        end

      Map.put(acc, key, new_value)
    end)
  end

  defp write_file(map, path) do
    new_env =
      map
      |> Enum.map(fn {key, value} ->
        key <> "=" <> value
      end)
      |> Enum.join("\n")

    File.write!(path, new_env)
  end
end
