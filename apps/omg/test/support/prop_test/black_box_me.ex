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

defmodule OMG.PropTest.BlackBoxMe do
  @moduledoc """
  Generates dumb wrapper for pure library that keeps state in process dictionary.
  Wrapper creates module.

  Example:
  ```
  OMG.PropTest.BlackBoxMe.create(YourProject.State.Core, CoreGS) # generate module name CoreGS
  ```
  would create a ```YourProject.State.CoreGS``` module, accessible in every ```MIX_ENV```.

  Pure library is presumed to have following interface:
  ```
  @spec funX(arg1, ..., argN, state) :: {:ok, side_effects(), state} | {{:error, term}, state}
  ```
  Wrapper exports the same functions with arity-1 (state is hidden) and returns tuples that are shorted by one item (state is hidden). Example above would have been transformed into:
  ```
  @spec funX(arg1, ..., argN) :: {:ok, side_effects()} | {:error, term}
  ```

  This allows for black-box testing and more importantly - for interaction with proper_statem and proper_fsm.

  Wrapper adds following helper functions:

  set state in process dictionary
  ```elixir
  @spec set_state( state() | nil) :: state() | nil
  ```
  get state stored in process dictionary (for possible inspection)
  ```
  @spec get_state() :: state() | nil
  ```
  """
  defp state_functions(core) do
    quote do
      def set_state(state) do
        Process.put(unquote(core), state)
      end

      def get_state do
        Process.get(unquote(core))
      end
    end
  end

  defp create_wrapper_function({func_name, arity}, core) do
    args = Macro.generate_arguments(arity - 1, nil)

    quote do
      def unquote(func_name)(unquote_splicing(args)) do
        state = get_state()

        case :erlang.apply(unquote(core), unquote(func_name), unquote(args) ++ [state]) do
          {:ok, side_effects, new_state} ->
            set_state(new_state)
            {:ok, side_effects}

          {:ok, new_state} ->
            set_state(new_state)
            :ok

          {{:error, error}, new_state} ->
            set_state(new_state)
            {:error, error}

          unexpected ->
            IO.puts(
              "unexpected output #{inspect(unquote(func_name)(unquote_splicing(args)))} :: #{inspect(unexpected)}"
            )

            :erlang.error({:badreturn, unexpected})
        end
      end
    end
  end

  @doc """
  generate module name CoreGS
  ```
  OMG.PropTest.BlackBoxMe.create(YourProject.State.Core, CoreGS)
  ```
  """
  defmacro create({:__aliases__, _, list_atoms}, {:__aliases__, _, dest}) do
    core = Module.concat(list_atoms)
    module_name = Module.concat(dest)

    contents =
      :functions
      |> core.__info__()
      |> Enum.filter(fn {function_name, _} -> !MapSet.member?(MapSet.new([:__info__, :__struct__]), function_name) end)
      |> Enum.map(&create_wrapper_function(&1, core))
      |> List.insert_at(0, state_functions(core))

    {:module, _, _, _} = Module.create(module_name, contents, Macro.Env.location(__ENV__))
    []
  end
end
