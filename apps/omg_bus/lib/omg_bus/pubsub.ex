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

defmodule OMG.Bus.PubSub do
  @moduledoc """
  Thin wrapper around the pubsub mechanism allowing us to not repeat ourselves when starting/broadcasting/subscribing

  All of the messages published will have `:internal_bus_event` prepended to the tuple to distinguish them

  ### Topics and messages

  #### `enqueue_block`

  Is being broadcast on a local node whenever `OMG.State` completes forming of a new child chain block

  Message: {:internal_event_bus, :enqueue_block, OMG.Block.t()}
  """
  alias Phoenix.PubSub

  def child_spec(args \\ []) do
    args
    |> Keyword.put_new(:name, __MODULE__)
    |> Keyword.put_new(:adapter, PubSub.PG2)
    |> PubSub.child_spec()
  end

  defmacro __using__(_) do
    quote do
      alias OMG.Bus.Event
      alias Phoenix.PubSub

      @doc """
      Fixes the name of the PubSub server and the variant of `Phoenix.PubSub` used
      """

      @doc """
      Subscribes the current process to the internal bus topic
      """
      def subscribe(topic, opts \\ [])

      def subscribe({origin, topic}, opts) when is_atom(origin) do
        PubSub.subscribe(OMG.Bus.PubSub, "#{origin}:#{topic}", opts)
      end

      def subscribe(topic, opts) do
        PubSub.subscribe(OMG.Bus.PubSub, topic, opts)
      end

      @doc """
      Broadcast a message with a prefix indicating that it is originating from the internal event bus

      Handle the message in the receiving process by e.g.
      ```
      def handle_info({:internal_bus_event, :some_event, my_payload}, state)
      ```
      """
      def broadcast(%Event{topic: topic, event: event, payload: payload}) when is_atom(event) do
        PubSub.broadcast(OMG.Bus.PubSub, topic, {:internal_event_bus, event, payload})
      end

      @doc """
      Same as `broadcast/1`, but performed on the local node
      """
      def direct_local_broadcast(%Event{topic: topic, event: event, payload: payload})
          when is_atom(event) do
        node_name = PubSub.node_name(OMG.Bus.PubSub)
        PubSub.direct_broadcast(node_name, OMG.Bus.PubSub, topic, {:internal_event_bus, event, payload})
      end
    end
  end
end
