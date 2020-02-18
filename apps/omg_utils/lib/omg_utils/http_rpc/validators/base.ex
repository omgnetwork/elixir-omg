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

defmodule OMG.Utils.HttpRPC.Validator.Base do
  @moduledoc """
  Implements simple validation engine with basic validators provided and allows to chain them
  to make more comprehensive one.
  """

  alias OMG.Utils.HttpRPC.Encoding

  @type validation_error_t() :: {:error, {:validation_error, binary(), any()}}

  # Creates a named chain of basic validators aka alias, for easier to use.
  # IMPORTANT: Alias can use already defined validators, not other aliases (no backtracking)
  @aliases %{
    address: [:hex, length: 20],
    hash: [:hex, length: 32],
    signature: [:hex, length: 65],
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
  * `expect(args, "arg_name", [:integer, greater: 1000])`
    Validate and positive integer greater than 1000

  * `expect(args, "arg_name", [:integer, :optional])`
  Validate integer value or when `arg_name` key is missing {:ok, `nil`} is returned

  * `expect(args, "arg_name", [:optional, :integer])`
    NOTE: **invalid order** it's the same as just `:integer`
    To validate optional integer values it should be `:integer, :optional`
  """
  @spec expect(map(), atom() | binary(), atom() | list()) :: {:ok, any()} | validation_error_t()
  def expect(map, key, atom) when is_atom(atom), do: expect(map, key, [atom])

  def expect(map, key, opts) do
    opts
    |> replace_aliases()
    |> Enum.reduce(
      map |> get(key),
      &validate/2
    )
    |> case do
      {val, []} -> {:ok, val}
      {_, [err | _]} -> error(key, err)
    end
  end

  @doc """
  Creates custom validation error
  """
  @spec error(binary(), any()) :: validation_error_t()
  def error(parent_name, {:validation_error, child_name, reason}),
    do: error(parent_name <> "." <> child_name, reason)

  def error(param_name, reason) when is_binary(param_name),
    do: {:error, {:validation_error, param_name, reason}}

  @doc """
  Unwraps elements from the results list: `[{:ok, elt} | {:error, any()}]` or returns the first error
  """
  @spec all_success_or_error([{:ok, any()} | {:error, any()}]) :: list() | {:error, any()}
  def all_success_or_error(result_list) do
    with nil <- result_list |> Enum.find(&(:error == Kernel.elem(&1, 0))),
         do:
           result_list
           |> Enum.map(fn {:ok, elt} -> elt end)
  end

  @doc """
  `integer` function is an example of basic validator used by the engine.
  Validators are passed to the `expect` function in `opts` parameter as a keyword list.
  Each validator expects a tuple, where first element is value of specified `key` in `map`
  possibly processed by previous validators in `opts` list. Second element is a validator list
  which fails on the value.
  It depends on validator but usually if some previous validator returns error on value, others
  just pass the error through and do not add themselves to the list.
  """
  @spec integer({any(), list()}) :: {any(), list()}
  def integer({_, [_ | _]} = err), do: err
  def integer({val, []} = acc) when is_integer(val), do: acc
  def integer({val, []}), do: {val, [:integer]}

  @spec optional({any(), list()}) :: {any(), list()}
  def optional({val, _}) when val in [:missing, nil], do: {nil, []}
  def optional(acc), do: acc

  @spec optional({any(), list()}, atom()) :: {any(), list()}
  def optional({val, _}, true) when val in [:missing, nil], do: {nil, []}
  def optional(acc, _), do: acc

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

  @spec max_length({any(), list()}, non_neg_integer()) :: {any(), list()}
  def max_length({_, [_ | _]} = err, _len), do: err
  def max_length({list, []}, len) when is_list(list) and length(list) <= len, do: {list, []}
  def max_length({val, []}, len), do: {val, max_length: len}

  @spec greater({any(), list()}, integer()) :: {any(), list()}
  def greater({_, [_ | _]} = err, _b), do: err
  def greater({val, []}, bound) when is_integer(val) and val > bound, do: {val, []}
  def greater({val, []}, _b) when not is_integer(val), do: {val, [:integer]}
  def greater({val, []}, bound), do: {val, greater: bound}

  @spec list({any(), list()}, function() | nil) :: {any(), list()}
  def list(tuple, mapper \\ nil)
  def list({_, [_ | _]} = err, _), do: err
  def list({val, []}, nil) when is_list(val), do: {val, []}
  def list({val, []}, mapper) when is_list(val), do: list_processor(val, mapper)
  def list({val, _}, _), do: {val, [:list]}

  @spec map({any(), list()}, function() | nil) :: {any(), list()}
  def map(tuple, parser \\ nil)
  def map({_, [_ | _]} = err, _), do: err
  def map({val, []}, nil) when is_map(val), do: {val, []}

  def map({val, []}, parser) when is_map(val),
    do:
      (case parser.(val) do
         {:error, err} -> {val, [err]}
         {:ok, map} -> {map, []}
       end)

  def map({val, _}, _), do: {val, [:map]}

  defp list_processor(val, mapper) do
    list_reducer = fn
      {:error, map_err}, _acc -> {:halt, map_err}
      {:ok, elt}, acc -> {:cont, [elt | acc]}
      elt, acc -> {:cont, [elt | acc]}
    end

    val
    |> Enum.reduce_while([], fn elt, acc -> mapper.(elt) |> list_reducer.(acc) end)
    |> case do
      list when is_list(list) ->
        {Enum.reverse(list), []}

      err ->
        {val, [err]}
    end
  end

  # provides initial value to the validators reducer, see: `expect`
  defp get(map, key), do: {Map.get(map, key, :missing), []}

  defp validate(validator, acc) when is_atom(validator), do: Kernel.apply(__MODULE__, validator, [acc])
  defp validate({validator, args}, acc), do: Kernel.apply(__MODULE__, validator, [acc, args])

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
