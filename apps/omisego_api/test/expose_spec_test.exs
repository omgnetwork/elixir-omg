# Copyright 2017 OmiseGO Pte Ltd
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

defmodule OmiseGO.API.ExposeSpecTest do
  use ExUnit.Case

  defmodule SomeModule do
    use OmiseGO.API.ExposeSpec

    @spec basic(x :: integer, y :: integer) :: integer
    def basic(x, y) do
      x + y
    end

    @spec complex_return(x :: integer) :: {:ok, integer}
    def complex_return(x) do
      {:ok, x + 2}
    end

    # lazy programmer: mentions type but not the variable name, parses OK
    @spec lazy(integer) :: {:ok, integer}
    def lazy(x) do
      {:ok, x + 2}
    end

    # lazy programmer: mentions type but not the variable name, parses OK
    @spec lists(integer) :: {:ok, [integer]}
    def lists(x) do
      {:ok, [x + 2]}
    end

    # parse result here is a bit ugly because series
    # of alternatives are nested in quoted (AST)
    @spec alts(x :: {:ok, integer | float}) :: {:ok, integer} | :error | :error2
    def alts(x) do
      {:ok, x + 2}
    end

    # this one is too complex - will be just dropped by OmiseGO.API.ExposeSpec
    @spec aliased(x) :: x when x: integer
    def aliased(x) do
      x + 1
    end

    @spec exported(x :: integer) :: {:ok, Map.t(), :queue.queue()}
    def exported(x) do
      {:ok, Map.new([x]), :queue.new([x])}
    end

    @spec triple(x :: {integer, integer, integer}) :: :ok
    def triple(_x) do
      :ok
    end
  end

  test "expected list of parsed specs" do
    assert [:alts, :basic, :complex_return, :exported, :lazy, :lists, :triple] ==
             Enum.sort(Map.keys(SomeModule.get_specs()))
  end

  test "parses aliased types" do
    assert {:ok, :"Map.t", :"queue.queue"} == SomeModule.get_specs()[:exported][:returns]
  end

  test "test one spec" do
    assert SomeModule.get_specs().lazy == %{args: [:integer], arity: 1, name: :lazy, returns: {:ok, :integer}}
  end

  test "test triple" do
    assert SomeModule.get_specs().triple ==
             %{args: [{:x, {:integer, :integer, :integer}}], arity: 1, name: :triple, returns: :ok}
  end
end
