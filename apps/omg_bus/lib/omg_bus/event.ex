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
  @type topic_t() :: {:child_chain, binary()} | {:root_chain, binary()} | binary()
  @type t() :: %__MODULE__{topic: __MODULE__.topic_t(), event: atom, payload: any()}

  defstruct [:topic, :event, :payload]

  @root_chain_topic_prefix "root_chain:"
  @child_chain_topic_prefix "child_chain:"

  @spec new(__MODULE__.topic_t(), atom(), any()) :: __MODULE__.t()
  def new(topic, event, payload)

  def new({:child_chain, topic}, event, payload) when is_atom(event) do
    %__MODULE__{topic: @child_chain_topic_prefix <> topic, event: event, payload: payload}
  end

  def new({:root_chain, topic}, event, payload) when is_atom(event) do
    %__MODULE__{topic: @root_chain_topic_prefix <> topic, event: event, payload: payload}
  end
end
