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

defmodule OMG.Status.Metric.Measure do
  @moduledoc """
  Wrapper around facilities used to trigger events to calculate performance metrics

  Allows one to discard some metric triggers, based on their namespace:
  ## Example

      config :omg_status, discard_metrics: [:State]
  """

  use Decorator.Define,
    measure_start: 0,
    measure_event: 0

  alias OMG.Status.Metric.Tracer

  @discard_namespace_metrics Application.get_env(:omg_status, :discard_metrics, [])

  def measure_start(body, context) do
    # NOTE: the namespace and event group naming convention here is tentative.
    # It is possible we'll revert to standard coarser division into `web` and `background` namespaces Appsignal suggests
    if Enum.find(@discard_namespace_metrics, &match?(^&1, namespace(context))),
      do: body,
      else: start_trace(body, context)
  end

  def measure_event(body, context) do
    if Enum.find(@discard_namespace_metrics, &match?(^&1, namespace(context))),
      do: body,
      else: start_span(body, context)
  end

  ### macros implementation reference https://github.com/spandex-project/spandex/blob/master/lib/decorators.ex
  defp start_trace(body, context) do
    trace_name = trace_name(context)

    quote do
      _ = unquote(Tracer).start_trace(unquote(trace_name))
      Logger.metadata(span_id: unquote(Tracer).current_span_id())
      result = unquote(body)
      _ = unquote(Tracer).finish_trace()

      result
    end
  end

  defp start_span(body, context) do
    trace_name = trace_name(context)

    quote do
      _ =
        unquote(Tracer).start_span(
          unquote(trace_name),
          [{:resource, unquote(trace_name)}]
        )

      Logger.metadata(span_id: unquote(Tracer).current_span_id())
      result = unquote(body)
      _ = unquote(Tracer).finish_span()

      result
    end
  end

  defp trace_name(%{module: module, name: function, arity: arity}) do
    module =
      module
      |> Atom.to_string()
      |> String.trim_leading("Elixir.")

    "#{module}.#{function}/#{arity}"
  end

  defp namespace(%{module: module}) do
    module
    |> Module.split()
    |> List.last()
    |> String.to_existing_atom()
  end
end
