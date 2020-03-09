defmodule StatusTests do
  use Cabbage.Feature, async: false, file: "status.feature"

  require Logger

  defwhen ~r/Alice checks the Watcher's status$/, %{service: service}, state do
    {:ok, response} = WatcherSecurityCriticalAPI.Api.Status.status_get(WatcherSecurityCriticalAPI.Connection.new())
    body = Jason.decode!(response.body)
    {:ok, Map.put(state, :status_response, body)}
  end

  defthen ~r/^Alice can read last_seen_eth_block_number as an integer$/, %{}, state do
    assert is_integer(state.status_response["last_seen_eth_block_number"])
    {:ok, state}
  end

  defthen ~r/^Alice can read last_seen_eth_block_timestamp as an integer$/, %{}, state do
    assert is_integer(state.status_response["last_seen_eth_block_number"])
    {:ok, state}
  end

  defthen ~r/^Alice can read eth_syncing as a boolean$/, %{}, state do
    assert is_boolean(state.status_response["eth_syncing"])
    {:ok, state}
  end

  defthen ~r/^Alice can read contract_addr as a map$/, %{}, state do
    assert is_map(state.status_response["contract_addr"])
    {:ok, state}
  end

  defthen ~r/^Alice can read the plasma framework's contract address$/, %{}, state do
    assert "0x" <> address = state.status_response["contract_addr"]["plasma_framework"]
    assert String.length(address) == 40
    {:ok, state}
  end

  defthen ~r/^Alice can read the ETH vault's contract address$/, %{}, state do
    assert "0x" <> address = state.status_response["contract_addr"]["eth_vault"]
    assert String.length(address) == 40
    {:ok, state}
  end

  defthen ~r/^Alice can read the ERC-20 vault's contract address$/, %{}, state do
    assert "0x" <> address = state.status_response["contract_addr"]["erc20_vault"]
    assert String.length(address) == 40
    {:ok, state}
  end

  defthen ~r/^Alice can read the payment exit game's contract address$/, %{}, state do
    assert "0x" <> address = state.status_response["contract_addr"]["payment_exit_game"]
    assert String.length(address) == 40
    {:ok, state}
  end

  defthen ~r/^Alice can read the name and synced height of each internal service$/, %{}, state do
    :ok = Enum.each(state.status_response["services_synced_heights"], fn services ->
      assert is_integer(services["height"])
      assert is_binary(services["service"])
    end)

    {:ok, state}
  end
end
