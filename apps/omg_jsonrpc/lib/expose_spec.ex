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

defmodule OMG.JSONRPC.ExposeSpec do
  @moduledoc """
  `use OMG.JSONRPC.ExposeSpec` to expose all @spec in the runtime via YourModule.get_specs()

  NOTE: this is a stripped down version of ExposeSpec. The original one parsed `@spec` annotations automatically

  This version requires to give and maintain `@expose_spec` annotations for every exposed function.
  `@expose_spec` annotations follow the following convention:

  ```
  @spec get_block(hash :: bitstring) ::
          {:ok, %{hash: bitstring, transactions: list, number: integer}} | {:error, :not_found | :internal_error}
  @expose_spec {:get_block,
                %{
                  args: [hash: :bitstring],
                  arity: 1,
                  name: :get_block,
                  returns:
                    {:alternative,
                     [
                       ok: {:map, [hash: :bitstring, transactions: :list, number: :integer]},
                       error: {:alternative, [:not_found, :internal_error]}
                     ]}
                }}
  ```

  The reason to strip down was achieving quick compatibility with Elixir 1.7, where `Module.get_attribute(module, :spec)`
  [doesn't work anymore](https://elixirforum.com/t/since-elixir-1-7-module-get-attributes-module-spec-returns-nil/15808)
  and git blame for the original version.
  """

  @typedoc """
  Describes function: it's name, arity, list of arguments and their types, return type.
  """
  @type spec :: %{name: atom(), arity: arity(), args: [{atom(), type()}], returns: type()}

  @typedoc """
  Describes Elixir type. For details see https://hexdocs.pm/elixir/typespecs.html

  Note that tuple() denotes tuple of any size where all elements are of type type()
  """
  @type type() :: atom | tuple() | {:alternatives, [type()]}

  # Sanity check since functions of the same name
  # but different arity are not yet handled.
  defp arity_sanity_check(list) do
    names = for {name, _} <- list, do: name
    testresult = length(Enum.uniq(names)) != length(names)
    if testresult, do: :problem_with_arity, else: :ok
  end

  defmacro __using__(_opts) do
    quote do
      import OMG.JSONRPC.ExposeSpec

      Module.register_attribute(__MODULE__, :expose_spec, accumulate: true)

      @before_compile OMG.JSONRPC.ExposeSpec
    end
  end

  defmacro __before_compile__(env) do
    module = env.module

    nice_spec =
      module
      |> Module.get_attribute(:expose_spec)

    :ok = arity_sanity_check(nice_spec)
    escaped = Macro.escape(Map.new(nice_spec))

    quote do
      def get_specs, do: unquote(escaped)
    end
  end
end
