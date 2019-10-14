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

defmodule OMG.EthereumEventListener.Groomer do
  @moduledoc """
  Handles various business-logic specific processing of ethereum events
  """

  @doc """
  Applies the grooming procedure to the event received from `OMG.Eth`
  """
  @spec apply(%{required(:event_signature) => binary(), optional(any()) => any()}) :: map()
  def apply(%{event_signature: "InFlightExitInput" <> _} = raw_event),
    do: Map.update(raw_event, :omg_data, %{piggyback_type: :input}, &Map.put(&1, :piggyback_type, :input))

  def apply(%{event_signature: "InFlightExitOutput" <> _} = raw_event),
    do: Map.update(raw_event, :omg_data, %{piggyback_type: :output}, &Map.put(&1, :piggyback_type, :output))

  def apply(%{event_signature: signature} = other_event) when is_binary(signature), do: other_event
end
