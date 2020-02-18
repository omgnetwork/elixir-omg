defmodule ServiceNameTests do
  use Cabbage.Feature, async: false, file: "service_name.feature"

  require Logger

  defwhen ~r/^Operator deploys "(?<service>[^"]+)"$/, %{service: service}, state do
    {:ok, response} =
      case service do
        "Child Chain" ->
          ChildChainAPI.Api.Alarm.alarm_get(ChildChainAPI.Connection.new())

        "Watcher" ->
          WatcherSecurityCriticalAPI.Api.Alarm.alarm_get(WatcherSecurityCriticalAPI.Connection.new())

        "Watcher Info" ->
          WatcherInfoAPI.Api.Alarm.alarm_get(WatcherInfoAPI.Connection.new())
      end

    body = Jason.decode!(response.body)
    {:ok, Map.put(state, :service_response, body)}
  end

  defthen ~r/^Operator can read its service name as "(?<service_name>[^"]+)"$/, %{service_name: service_name}, state do
    assert state.service_response["service_name"] == service_name

    {:ok, state}
  end
end
