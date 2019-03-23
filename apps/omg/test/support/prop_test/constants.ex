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

defmodule OMG.PropTest.Constants do
  @moduledoc false
  defmacro eth, do: <<0::160>>
  defmacro other_currency, do: <<1::160>>
  defmacro child_block_interval, do: 1_000

  defmacro currencies, do: quote(do: %{eth: unquote(eth()), other: unquote(other_currency())})
end
