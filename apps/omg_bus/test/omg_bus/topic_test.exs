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

defmodule OMG.Bus.TopicTest do
  @moduledoc false

  use ExUnit.Case

  alias OMG.Bus.Topic

  test "creates a root chain topic" do
    topic = "Deposit"
    assert %Topic{topic: "root_chain:" <> topic} == Topic.root_chain_topic(topic)
  end

  test "creates a child chain topic" do
    topic = "blocks"
    assert %Topic{topic: "child_chain:" <> topic} == Topic.child_chain_topic(topic)
  end
end
