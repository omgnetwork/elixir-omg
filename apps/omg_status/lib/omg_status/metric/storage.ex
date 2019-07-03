# Copyright 2019 OmiseGO Pte Ltd
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

defmodule Storage do
  @moduledoc false
  use GenServer

  def exchange(name, value) do
    GenServer.call(__MODULE__, {name, value})
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(values) do
    {:ok, values}
  end

  def handle_call({name, value}, _rom, storage) do
    {:reply, Map.get(storage, name, value), Map.put(storage, name, value)}
  end
end
