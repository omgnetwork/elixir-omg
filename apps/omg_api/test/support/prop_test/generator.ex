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

defmodule OMG.API.State.PropTest.Generators do
  @moduledoc """
  generators used in the sense of porpCheck
  """
  use OMG.API.LoggerExt
  import PropCheck.BasicTypes
  require PropCheck
  use PropCheck
  require OMG.API.State.PropTest.Constants
  alias OMG.API.State.PropTest.Constants

  def fixed_list(_, 0), do: []

  def fixed_list(type, size) do
    fixed_list([type | fixed_list(type, size - 1)])
  end

  def input_transaction(spendable) do
    frequency([
      {1, fixed_list([oneof(spendable)])},
      {1, fixed_list([oneof(spendable), oneof(spendable)])}
    ])
  end

  def new_owners do
    users = OMG.API.TestHelper.entities_stable() |> Map.keys()

    frequency([
      {1, fixed_list([oneof(users)])},
      {1, fixed_list([oneof(users), oneof(users)])}
    ])
  end

  def get_currency do
    frequency([{7, Constants.ethereum()}, {1, Constants.other_currency()}])
  end

  def entity do
    addresses =
      OMG.API.TestHelper.entities_stable()
      |> Map.values()

    oneof(addresses)
  end
end
