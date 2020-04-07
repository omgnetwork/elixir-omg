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

defmodule OMG.Bus.EventTest do
  @moduledoc false

  use ExUnit.Case

  alias OMG.Bus.Event

  test "creates a root chain event" do
    topic = "Deposit"
    event = :deposit
    payload = ["payload"]

    assert %Event{topic: "root_chain:" <> topic, event: event, payload: payload} ==
             Event.new({:root_chain, topic}, event, payload)
  end

  test "creates a child chain event" do
    topic = "blocks"
    event = :deposit
    payload = ["payload"]

    assert %Event{topic: "child_chain:" <> topic, event: event, payload: payload} ==
             Event.new({:child_chain, topic}, event, payload)
  end
end
