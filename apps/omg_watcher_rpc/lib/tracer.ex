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

defmodule OMG.WatcherRPC.Tracer do
  @moduledoc """
  Trace Phoenix requests and reports information to Datadog via Spandex
  """

  use Spandex.Tracer, otp_app: :omg_watcher_rpc

  @doc """
  Given conn and parsed response body, return a span with extra metadata.

  The service medata (default ':web') is overridden to be the name of the OMG service.

  Metadata added to the span is not arbitrary and is validated by Spandex against a schema:

  service(:atom) Required: The default service name to use for spans declared without a service
  env(:string): A name used to identify the environment name, e.g prod or development
  services([{:keyword, :atom}, :keyword]): A mapping of service name to the default span types. - Default: []
  completion_time(:integer)
  error(:keyword)
  http(:keyword)
  id(:any)
  name(:string)
  parent_id(:any)
  private(:keyword) - Default: []
  resource([:atom, :string])
  sql_query(:keyword)
  start(:integer)
  tags(:keyword) - Default: []
  trace_id(:any)
  type(:atom)
  """
  defp add_metadata_from_response_body(conn, json_resp_body) do
    service = String.to_atom(json_resp_body["service_name"])
    error = if !json_resp_body["success"], do: Keyword.new([{:error, true}])
    error_type = if !!error and json_resp_body["data"], do: json_resp_body["data"]["code"]
    error_msg = if !!error and json_resp_body["data"], do: json_resp_body["data"]["description"]

    tags = [
      {:version, json_resp_body["version"]}
    ]

    _ = if error_type, do: tags ++ {String.to_atom("error.type"), error_type}
    _ = if error_msg, do: tags ++ {String.to_atom("error.msg"), error_msg}

    trace_data =
      conn
      |> SpandexPhoenix.default_metadata()
      |> Keyword.put(:service, service)
      |> Keyword.put(:tags, tags)

    if error,
      do:
        trace_data
        |> Keyword.put(:error, error),
      else: trace_data
  end

  @doc """
  Adds metadata from the response body to the Spandex span.

  The conn is inspected just before sending back the API response.

  Handles failure to decode the response body gracefully.
  """

  def add_trace_metadata(conn) do
    case Jason.decode(conn.resp_body) do
      {:ok, json_resp_body} -> add_metadata_from_response_body(conn, json_resp_body)
      {:error, _} -> SpandexPhoenix.default_metadata(conn)
    end
  end
end
