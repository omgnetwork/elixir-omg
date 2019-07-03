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

defmodule OMG.Utils.Metrics do
  @moduledoc """
  Wrapper around facilities used to trigger events to calculate performance metrics

  Allows one to discard some metric triggers, based on their namespace:
  ## Example

      config :omg_utils, discard_metrics: [:State]
  """

  use Decorator.Define,
    measure_start: 0,
    measure_event: 0

  @discard_namespace_metrics Application.get_env(:omg_utils, :discard_metrics, [])

  def measure_start(body, context) do
    # NOTE: the namespace and event group naming convention here is tentative.
    # It is possible we'll revert to standard coarser division into `web` and `background` namespaces Appsignal suggests
    namespace = context.module |> Module.split() |> List.last() |> String.to_existing_atom()

    if Enum.find(@discard_namespace_metrics, &match?(^&1, namespace)),
      do: body,
      # TODO use spandex
      else: body
  end

  def measure_event(body, context) do
    event_group = context.module |> Module.split() |> List.last() |> String.to_existing_atom()

    if Enum.find(@discard_namespace_metrics, &match?(^&1, event_group)),
      do: body,
      # TODO use spandex
      else: body
  end

  def to_event_name(name, rest_key \\ [])

  def to_event_name(atom, rest_key) when is_atom(atom) do
    to_string(atom) |> to_event_name(rest_key)
  end

  def to_event_name(name, rest_key) when is_binary(name) do
    segments = String.split(name, ".")
    Enum.map(segments, &String.to_atom/1) ++ rest_key
  end
end
