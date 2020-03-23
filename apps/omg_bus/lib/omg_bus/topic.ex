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

defmodule OMG.Bus.Topic do
  @moduledoc """
  Representation of a topic on OMG event bus
  """
  @enforce_keys [:topic]
  @type t() :: %__MODULE__{topic: binary()}

  defstruct [:topic]

  @root_chain_topic_prefix "root_chain:"
  @child_chain_topic_prefix "child_chain:"

  def root_chain_topic(topic) do
    %__MODULE__{topic: @root_chain_topic_prefix <> topic}
  end

  def child_chain_topic(topic) do
    %__MODULE__{topic: @child_chain_topic_prefix <> topic}
  end
end
