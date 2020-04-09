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

defmodule OMG.Bus.Event do
  @moduledoc """
  Representation of a single event to be published on OMG event bus
  """

  @enforce_keys [:topic, :event, :payload]
  @type topic_t() :: {atom(), binary()} | binary()
  @type t() :: %__MODULE__{topic: binary(), event: atom, payload: any()}

  defstruct [:topic, :event, :payload]

  @spec new(__MODULE__.topic_t(), atom(), any()) :: __MODULE__.t()
  def new({origin, topic}, event, payload) when is_atom(origin) and is_atom(event) do
    %__MODULE__{topic: "#{origin}:#{topic}", event: event, payload: payload}
  end
end
