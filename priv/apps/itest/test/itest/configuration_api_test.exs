defmodule ConfigurationRetrievalTests do
  use Cabbage.Feature, async: true, file: "configuration_api.feature"
  alias Itest.Transactions.Encoding
  require Logger

  setup_all do
    data = ABI.encode("getVersion()", [])

    {:ok, response} =
      Ethereumex.HttpClient.eth_call(%{to: Itest.Account.plasma_framework(), data: Encoding.to_hex(data)})

    [{contract_semver}] =
      response
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([{:tuple, [:string]}])

    %{assert_response: %{"contract_semver" => contract_semver, "deposit_finality_margin" => 10}}
  end

  defwhen ~r/^Operator deploys "(?<service>[^"]+)"$/, %{service: service}, state do
    {:ok, response} =
      case service do
        "Child Chain" ->
          ChildChainAPI.Api.Configuration.configuration_get(ChildChainAPI.Connection.new())

        "Watcher" ->
          WatcherSecurityCriticalAPI.Api.Configuration.configuration_get(WatcherSecurityCriticalAPI.Connection.new())

        "Watcher Info" ->
          WatcherInfoAPI.Api.Configuration.configuration_get(WatcherInfoAPI.Connection.new())
      end

    body = Jason.decode!(response.body)
    {:ok, Map.put(state, :service_response, body)}
  end

  defthen ~r/^Operator can read its configurational values$/, _, state do
    assert state.service_response["data"] == state.assert_response
  end
end
