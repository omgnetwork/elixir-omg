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

defmodule OMG.RPC.Web.Validator.Base do
  @moduledoc """
  Implements simple validation engine with basic validators provided and allows to chain them
  to make more comprehensive one.
  """

  alias OMG.RPC.Web.Encoding

  # Creates a named chain of basic validators aka alias, for easier to use.
  # IMPORTANT: Alias can use already defined validators, not other aliases (no backtracking)
  @aliases %{
    address: [:hex, length: 20],
    hash: [:hex, length: 32],
    pos_integer: [:integer, greater: 0],
    non_neg_integer: [:integer, greater: -1]
  }

  @doc """
  Validates value of given key in the map with provided list of validators.
  First validator list is preprocessed which replaces aliases with its definitions.
  Then value is fetched from the map and each validator is run passing a tuple
  where first element is a value and second validation error from previous validator.
  If all validators succeed on the value the second element is empty list (no validation errors).
  Last result of the validation is translated to {:ok, value} or error.

  ## Examples
  * `param(args, "arg_name", :integer, greater: 1000)`
    Validate and positive integer greater than 1000

  * `param(args, "arg_name", :integer, :optional)`
  Validate integer value or when `arg_name` key is missing {:ok, `nil`} is returned

  * `param(args, "arg_name", :optional, :integer)`
    NOTE: **invalid order** it's the same as just `:integer`
    To validate optional integer values it should be `:integer, :optional`
  """
  @spec param(map(), atom() | binary(), atom() | list()) ::
          {:ok, any()} | {:error, {:validation_error, atom() | binary(), atom() | list()}}
  def param(map, key, atom) when is_atom(atom), do: param(map, key, [atom])

  def param(map, key, opts) do
    res =
      opts
      |> replace_aliases()
      |> Enum.reduce(
        {get(map, key), []},
        &validate/2
      )

    case res do
      {val, []} ->
        {:ok, val}

      {_, [err | _]} ->
        {:error, {:validation_error, key, err}}
    end
  end

  @spec integer({any(), list()}) :: {any(), list()}
  def integer({_, [_ | _]} = err), do: err
  def integer({val, []} = acc) when is_integer(val), do: acc
  def integer({val, []}), do: {val, [:integer]}

  @spec optional({any(), list()}) :: {any(), list()}
  def optional({val, _}) when val in [:missing, nil], do: {nil, []}
  def optional(acc), do: acc

  @spec hex({any(), list()}) :: {any(), list()}
  def hex({_, [_ | _]} = err), do: err

  def hex({str, []}) do
    with {:ok, bin} <- Encoding.from_hex(str) do
      {bin, []}
    else
      _ -> {str, [:hex]}
    end
  end

  @spec length({any(), list()}, non_neg_integer()) :: {any(), list()}
  def length({_, [_ | _]} = err, _len), do: err

  def length({str, []}, len) when is_binary(str) do
    if Kernel.byte_size(str) == len,
      do: {str, []},
      else: {str, length: len}
  end

  def length({val, []}, len), do: {val, length: len}

  @spec greater({any(), list()}, integer()) :: {any(), list()}
  def greater({_, [_ | _]} = err, _b), do: err
  def greater({val, []}, bound) when is_integer(val) and val > bound, do: {val, []}
  def greater({val, []}, _b) when not is_integer(val), do: {val, [:integer]}
  def greater({val, []}, bound), do: {val, greater: bound}

  defp get(map, key), do: Map.get(map, key, :missing)

  defp validate(validator, acc) when is_atom(validator), do: Kernel.apply(__MODULE__, validator, [acc])
  defp validate({validator, arg}, acc), do: Kernel.apply(__MODULE__, validator, [acc, arg])

  defp replace_aliases(validators) do
    validators
    |> Enum.reduce(
      [],
      fn v, acc ->
        key = validator_name(v)
        pre = Map.get(@aliases, key, [v])

        [_ | _] = acc ++ pre
      end
    )
  end

  defp validator_name(v) when is_atom(v), do: v
  defp validator_name({v, _}), do: v
end
