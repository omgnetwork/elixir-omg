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

defmodule OMG.Watcher.DatadogEvent.ContractEventConsumerTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias OMG.Watcher.DatadogEvent.ContractEventConsumer

  setup_all do
    Application.ensure_all_started(:omg_bus)

    on_exit(fn ->
      :ok = Application.stop(:omg_bus)
    end)
  end

  setup do
    pid = :erlang.pid_to_list(self())

    start_supervised(
      ContractEventConsumer.prepare_child(
        topic: "#{pid}",
        release: "child_chain",
        current_version: "test-123",
        publisher: __MODULE__.DatadogEventMock
      )
    )

    :ok
  end

  test "prepare_child sets a proper id" do
    topic = {:root_chain, "blocks"}
    %{id: id} = ContractEventConsumer.prepare_child(topic: topic)
    assert id == String.to_atom("root_chain:blocks_worker")
  end

  test "if an event put on omg bus is consumed by the event consumer and published on the publisher interface" do
    topic = self() |> :erlang.pid_to_list() |> to_string()
    sig = "#{topic}(bytes32)"
    data = [%{event_signature: sig}]
    event = %OMG.Bus.Event{topic: topic, event: :data, payload: data}
    OMG.Bus.direct_local_broadcast(event)
    assert_receive {:event, _, _}
  end

  test "if a list of events put on omg bus is consumed by the event consumer and published on the publisher interface" do
    topic = self() |> :erlang.pid_to_list() |> to_string()
    sig = "#{topic}(bytes32)"
    data = [%{event_signature: sig}, %{event_signature: sig}]
    event = %OMG.Bus.Event{topic: topic, event: :data, payload: data}
    OMG.Bus.direct_local_broadcast(event)
    assert_receive {:event, _, _}
  end

  defmodule DatadogEventMock do
    def event(title, message, options) do
      pid =
        title
        |> String.to_charlist()
        |> :erlang.list_to_pid()

      Kernel.send(pid, {:event, message, options})
      :ok
    end
  end
end
