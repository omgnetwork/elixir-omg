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
defmodule Itest.Transactions.Currency do
  @moduledoc false
  @ether <<0::160>>

  def ether(), do: @ether

  def to_wei(ether) when is_binary(ether) do
    ether
    |> String.to_integer()
    |> to_wei()
  end

  def to_wei(ether) when is_integer(ether), do: ether * 1_000_000_000_000_000_000
end
