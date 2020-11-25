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

defmodule OMG.Status.Metric.Telemetry do
  @moduledoc """
  Metrics handler to send telemetry events to Datadog
  """

  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(arg) do
    service = Keyword.fetch!(arg, :release)
    version = Keyword.fetch!(arg, :current_version)
    dd_host = Application.get_env(:statix, :host)
    dd_port = Application.get_env(:statix, :port)

    children = [
      {
        TelemetryMetricsStatsd,
        metrics: metrics(),
        global_tags: [
          version: version
        ],
        host: dd_host,
        port: dd_port,
        prefix: "omg.#{service}",
        formatter: :datadog
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp metrics() do
    [
      # Phoenix Metrics
      summary(
        "phoenix.endpoint.stop.duration",
        tags: [:version],
        unit: {:native, :millisecond}
      ),
      summary(
        "phoenix.router_dispatch.stop.duration",
        tags: [:version, :route],
        unit: {:native, :millisecond}
      ),
      summary(
        "phoenix.router_dispatch.exception.duration",
        tags: [:version, :kind],
        unit: {:native, :millisecond}
      ),
      summary(
        "phoenix.error_rendered.duration",
        tags: [:version, :kind],
        unit: {:native, :millisecond}
      ),

      # Custom web metrics
      counter(
        "web.fallback.error",
        tags: [:version, :route, :error_code]
      )
    ]
  end
end
