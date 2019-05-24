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

defmodule OMG.InternalEventBus do
  @moduledoc """
  Thin wrapper around the pubsub mechanism allowing us to not repeat ourselves when starting/broadcasting/subscribing

  All of the messages published will have `:internal_bus_event` prepended to the tuple to distinguish them

  ### Topics and messages

  #### `enqueue_block`

  Is being broadcast on a local node whenever `OMG.State` completes forming of a new child chain block

  Message: {:internal_event_bus, :enqueue_block, OMG.Block.t()}

  #### `emit_events`

  Is being broadcast to all nodes whenever an event trigger, that should be turned into a push event in `Eventer` occurs

  Message: {;internal_event, :emit_events, list()}
  """
  alias Phoenix.PubSub

  @doc """
  Fixes the name of the PubSub server and the variant of `Phoenix.PubSub` used
  """
  def child_spec(args \\ []) do
    args
    |> Keyword.put_new(:name, __MODULE__)
    |> PubSub.PG2.child_spec()
  end

  @doc """
  Subscribes the current process to the internal bus topic
  """
  def subscribe(topic, opts \\ []) do
    PubSub.subscribe(__MODULE__, topic, opts)
  end

  @doc """
  Broadcast a message with a prefix indicating that it is originating from the internal event bus

  Handle the message in the receiving process by e.g.
  ```
  def handle_info({:internal_bus_event, :some_event, my_payload}, state)
  ```
  """
  def broadcast(topic, {event, payload}) when is_atom(event) do
    PubSub.broadcast(__MODULE__, topic, {:internal_event_bus, event, payload})
  end

  @doc """
  Same as `broadcast/1`, but performed on the local node
  """
  def direct_local_broadcast(topic, {event, payload}) when is_atom(event) do
    PubSub.node_name(__MODULE__)
    |> PubSub.direct_broadcast(__MODULE__, topic, {:internal_event_bus, event, payload})
  end
end
