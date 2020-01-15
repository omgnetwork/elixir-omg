defmodule ServiceNameTests do
  use Cabbage.Feature, async: false, file: "service_name.feature"

  require Logger
  alias Itest.Client

  defwhen ~r/^Operator deploys "(?<service>[^"]+)"$/, %{service: service}, state do
    {:ok, response} =
      case service do
        "Child Chain" ->
          Client.get_child_chain_alarms()

        "Watcher" ->
          Client.get_watcher_alarms()

        "Watcher Info" ->
          Client.get_watcher_info_alarms()
      end

    body = Jason.decode!(response.body)
    {:ok, Map.put(state, :service_response, body)}
  end

  defthen ~r/^Operator can read it's service name as "(?<service_name>[^"]+)"$/, %{service_name: service_name}, state do
    case service_name do
      "watcher_info" ->
        # TODO remove when implemented
        assert state.service_response["service_name"] == "watcher"

      _ ->
        assert state.service_response["service_name"] == service_name
    end

    {:ok, state}
  end
end
