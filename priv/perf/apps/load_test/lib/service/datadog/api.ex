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

defmodule LoadTest.Service.Datadog.API do
  @datadog_events_api_path "api/v1/events"
  @datadog_app_url "https://app.datadoghq.com"
  @base_tags ["perf"]

  def assert_metrics(environment, start_datetime, end_datetime) do
    start_unix = DateTime.to_unix(start_datetime)
    end_unix = DateTime.to_unix(end_datetime)

    case fetch_events(start_unix, end_unix, environment) do
      {:ok, []} -> :ok
      {:ok, events} -> {:error, events}
      other -> other
    end
  end

  def fetch_events(start_time, end_time, environment) do
    params = %{
      start: start_time,
      end: end_time,
      tags: Enum.join(@base_tags, ","),
      unaggregated: true
    }

    headers = %{
      "Content-Type" => "application/json",
      "DD-API-KEY" => api_key(),
      "DD-APPLICATION-KEY" => app_key()
    }

    url = api_url() <> @datadog_events_api_path <> "?" <> URI.encode_query(params)

    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        events =
          body
          |> Jason.decode!()
          |> parse_events(environment)

        {:ok, events}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, error} ->
        {:error, error}
    end
  end

  defp parse_events(events_response, environment) do
    events_response["events"]
    |> Enum.filter(fn event ->
      event["alert_type"] == "error" and String.contains?(event["text"], environment)
    end)
    |> Enum.map(fn event ->
      {:ok, date} = DateTime.from_unix(event["date_happened"])

      %{
        "title" => event["title"],
        "url" => @datadog_app_url <> event["url"],
        "date" => date
      }
    end)
  end

  defp api_key() do
    Keyword.fetch!(datadog_config(), :api_key)
  end

  defp app_key() do
    Keyword.fetch!(datadog_config(), :app_key)
  end

  defp api_url() do
    Keyword.fetch!(datadog_config(), :api_url)
  end

  defp datadog_config() do
    Application.fetch_env!(:load_test, :datadog)
  end
end
