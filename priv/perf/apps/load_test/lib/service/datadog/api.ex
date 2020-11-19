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
  @moduledoc """
    Funcions for fetching monitor events from datadog.
  """

  require Logger

  @datadog_events_api_path "api/v1/events"
  @datadog_monitor_resolve_path "monitor/bulk_resolve"
  @datadog_app_url "https://app.datadoghq.com"

  def assert_metrics(environment, start_unix, end_unix)
      when is_integer(start_unix) and is_integer(end_unix) do
    # events aren't pulished instantly, so we will poll them
    do_assert_metrics(environment, start_unix, end_unix)
  end

  def assert_metrics(environment, start_datetime, end_datetime) do
    start_unix = DateTime.to_unix(start_datetime)
    end_unix = DateTime.to_unix(end_datetime)

    assert_metrics(environment, start_unix, end_unix)
  end

  def do_assert_metrics(environment, start_unix, end_unix, poll_count \\ 60) do
    case fetch_events(start_unix, end_unix, environment) do
      {:ok, []} ->
        case poll_count do
          0 ->
            :ok

          _ ->
            Process.sleep(1_000)
            do_assert_metrics(environment, start_unix, end_unix, poll_count - 1)
        end

      {:ok, events} ->
        # failed monitors with the same tags do not emit events, so we're resolving
        # failed monitors for future runs
        resolve_monitors(events)

        {:error, events}

      other ->
        other
    end
  end

  def fetch_events(start_time, end_time, environment, retries \\ 5) do
    params = %{
      start: start_time,
      end: end_time,
      tags: environment,
      unaggregated: true
    }

    url = api_url() <> @datadog_events_api_path <> "?" <> URI.encode_query(params)

    case HTTPoison.get(url, headers()) do
      {:ok, %{status_code: 200, body: body}} ->
        events =
          body
          |> Jason.decode!()
          |> parse_events(environment)

        {:ok, events}

      {:ok, %{body: body}} ->
        case retries do
          0 -> {:error, body}
          _ -> fetch_events(start_time, end_time, environment, retries - 1)
        end

      {:error, error} ->
        case retries do
          0 -> {:error, error}
          _ -> fetch_events(start_time, end_time, environment, retries - 1)
        end
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
        "date" => date,
        "monitor_id" => find_monitor_id(event["text"])
      }
    end)
  end

  defp resolve_monitors(events) do
    params =
      events
      |> Enum.map(fn event -> event["monitor_id"] end)
      |> Enum.filter(fn id -> !(is_nil(id) or id == "") end)
      |> Enum.uniq()
      |> Enum.map(fn id -> %{id => "ALL_GROUPS"} end)

    do_resolve_monitors(params)
  end

  defp do_resolve_monitors(params, retries \\ 5)

  defp do_resolve_monitors([], _), do: :ok

  defp do_resolve_monitors(params, retries) do
    payload = Jason.encode!(%{"resolve" => params})

    url = api_url() <> @datadog_monitor_resolve_path

    case HTTPoison.post(url, payload, headers()) do
      {:ok, %{status_code: 200}} ->
        :ok

      {:ok, %{body: body}} ->
        Logger.error("failed to resolve monitors #{inspect(body)}")

        case retries do
          0 ->
            {:error, body}

          _ ->
            Process.sleep(1_000)
            do_resolve_monitors(params, retries - 1)
        end

      {:error, error} = other ->
        Logger.error("failed to resolve monitors #{inspect(error)}")

        case retries do
          0 ->
            other

          _ ->
            Process.sleep(1_000)
            do_resolve_monitors(params, retries - 1)
        end
    end
  end

  defp find_monitor_id(text) do
    case String.split(text, ["monitors#", "?to_ts"], parts: 3) do
      [_, id, _] -> String.to_integer(id)
      _ -> nil
    end
  end

  defp headers() do
    %{
      "Content-Type" => "application/json",
      "DD-API-KEY" => api_key(),
      "DD-APPLICATION-KEY" => app_key()
    }
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
