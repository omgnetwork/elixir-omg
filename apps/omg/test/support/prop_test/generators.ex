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

defmodule OMG.PropTest.Generators do
  @moduledoc """
  Custom generators
  For our properties to be even more useful.
  Module created to contain all kinds of custom generators in the sense of propCheck,
  that are use in prop_test
  """

  alias OMG.PropTest.Constants
  alias PropCheck.BasicTypes
  use PropCheck
  import BasicTypes
  require PropCheck
  require Constants

  @doc """
  All lists whose i-th element is an instance of the type returned by applying func to i-th arg  
  """
  @spec fixed_list((any -> BasicTypes.type()), [any]) :: BasicTypes.type()
  def fixed_list(func, [arg | rest]), do: fixed_list([func.(arg) | fixed_list(func, rest)])
  def fixed_list(_type, []), do: []

  @doc """
  All lists fixed size whose all element is an instance of the type   
  """
  @spec fixed_list(BasicTypes.type(), non_neg_integer) :: BasicTypes.type()
  def fixed_list(_, 0), do: []
  def fixed_list(type, size), do: fixed_list([type | fixed_list(type, size - 1)])

  @spec input_transaction([any]) :: BasicTypes.type()
  def input_transaction(spendable) do
    frequency([
      {1, fixed_list([oneof(spendable)])},
      {1, fixed_list([oneof(spendable), oneof(spendable)])}
    ])
  end

  @spec entitie_atom() :: BasicTypes.type()
  def entitie_atom, do: oneof(OMG.TestHelper.entities_stable() |> Map.keys())

  @spec new_owners() :: BasicTypes.type()
  def new_owners do
    frequency([
      {1, fixed_list([{entitie_atom(), choose(1, 30)}])},
      {1, fixed_list({entitie_atom(), choose(1, 30)}, 2)}
    ])
  end

  @spec get_currency() :: BasicTypes.type()
  def get_currency do
    frequency([{7, Constants.eth()}, {1, Constants.other_currency()}])
  end

  @spec entity() :: BasicTypes.type()
  def entity do
    addresses =
      OMG.TestHelper.entities_stable()
      |> Map.values()

    oneof(addresses)
  end

  @spec add_random(BasicTypes.ext_int(), {BasicTypes.ext_int(), BasicTypes.ext_int()}) :: BasicTypes.type()
  def add_random(number, {from, to}) do
    choose(number + from, number + to)
  end
end
