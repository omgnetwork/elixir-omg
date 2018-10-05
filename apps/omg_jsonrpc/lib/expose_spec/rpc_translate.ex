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

defmodule OMG.JSONRPC.ExposeSpec.RPCTranslate do
  @moduledoc """
  Translates an incoming call to a form that can be executed with `:erlang.apply/3`

  The incoming call can originate from the JSONRPC handler or the Websockets handler (or other).

  Returns JSONRPC2-like error values if there is a problem.
  """

  @type function_name :: binary
  @type arg_name :: binary
  @type spec :: OMG.JSONRPC.ExposeSpec.spec()
  @type json_args :: %{required(arg_name) => any}
  @type rpc_error :: {:method_not_found, map} | {:invalid_params, map}

  @doc """
  `to_fa/3` transforms JSONRPC2 method and params to Elixir's Function and Arguments,
  since the naming. See also type mfa() in Elixir's typespecs.
  """
  @spec to_fa(method :: function_name, params :: json_args, spec :: spec) :: {:ok, atom, list(any)} | rpc_error
  def to_fa(method, params, spec, on_match \\ &on_match_default/3) do
    with {:ok, fname} <- existing_atom(method),
         :ok <- is_exposed(fname, spec),
         {:ok, args} <- get_args(fname, params, spec, on_match),
         do: {:ok, fname, args}
  end

  defp on_match_default(_name, _type, value), do: {:ok, value}

  @spec existing_atom(method :: function_name) :: {:ok, atom} | {:method_not_found, map}
  defp existing_atom(method) do
    try do
      {:ok, String.to_existing_atom(method)}
    rescue
      ArgumentError -> {:method_not_found, %{method: method}}
    end
  end

  @spec is_exposed(fname :: atom, spec :: spec) :: :ok | {:method_not_found, map}
  defp is_exposed(fname, spec) do
    case fname in Map.keys(spec) do
      true -> :ok
      false -> {:method_not_found, %{method: fname}}
    end
  end

  @spec get_args(fname :: atom, params :: json_args, spec :: spec, on_match :: fun()) ::
          {:ok, list(any)} | {:invalid_params, map}
  defp get_args(fname, params, spec, on_match) when is_map(params) do
    validate_args = fn {name, type} = argspec, list ->
      value = Map.get(params, Atom.to_string(name))
      value = on_match.(name, type, value)

      # value has been looked-up in params and possibly decoded by handler-specific code.
      # If either failed an arg was missing or given badly
      case value do
        {:error, _} ->
          {:halt, {:missing_arg, argspec}}

        nil ->
          {:halt, {:missing_arg, argspec}}

        {:ok, value} ->
          {:cont, list ++ [value]}
      end
    end

    case Enum.reduce_while(spec[fname].args, [], validate_args) do
      {:missing_arg, {name, type}} ->
        msg = "Please provide parameter `#{name}` of type `#{inspect(type)}`"
        {:invalid_params, %{msg: msg, name: name, type: type}}

      args ->
        {:ok, args}
    end
  end

  defp get_args(_, _, _, _) do
    {:invalid_params, %{msg: "params should be a JSON key-value pair array"}}
  end
end
