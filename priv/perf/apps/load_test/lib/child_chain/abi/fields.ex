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

defmodule LoadTest.ChildChain.Abi.Fields do
  @moduledoc """
  Adapt to naming from contracts to elixir-omg.

  I need to do this even though I'm bleeding out of my eyes.
  """
  def rename(data, %ABI.FunctionSelector{function: "DepositCreated"}) do
    # key is naming coming from plasma contracts
    # value is what we use
    contracts_naming = [{"token", :currency}, {"depositor", :owner}, {"blknum", :blknum}, {"amount", :amount}]

    reduce_naming(data, contracts_naming)
  end

  defp reduce_naming(data, contracts_naming) do
    Enum.reduce(contracts_naming, %{}, fn
      {old_name, new_name}, acc ->
        value = Map.get(data, old_name)

        acc
        |> Map.put_new(new_name, value)
        |> Map.delete(old_name)
    end)
  end
end
