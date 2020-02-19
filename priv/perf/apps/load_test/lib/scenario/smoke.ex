defmodule LoadTest.Scenario.Smoke do
  @moduledoc """
  Smoke test scenerio to ensure services are up
  """
  use Chaperon.Scenario

  def run(session) do
    session |> log_info("run smoke test to make sure services are up...")

    check_child_chain_up()
    check_watcher_security_up()
    check_watcher_info_up()

    session |> log_info("smoke test done...")
  end

  defp check_child_chain_up() do
    {:ok, response} =
      LoadTest.Connection.ChildChain.client()
      |> ChildChainAPI.Api.Configuration.configuration_get()

    # some sanity check
    %{
      "data" => %{
        "contract_semver" => _contract_semver,
        "deposit_finality_margin" => _deposit_finality_margin,
        "network" => _netowork
      },
      "service_name" => "child_chain"
    } = Jason.decode!(response.body)
  end

  defp check_watcher_security_up() do
    {:ok, response} =
      LoadTest.Connection.WatcherSecurity.client()
      |> WatcherSecurityCriticalAPI.Api.Status.status_get()

    # some sanity check
    %{
      "data" => %{
        "byzantine_events" => _byzantine_events,
        "contract_addr" => _contract_addr
      },
      "service_name" => "watcher"
    } = Jason.decode!(response.body)
  end

  defp check_watcher_info_up() do
    {:ok, response} =
      LoadTest.Connection.WatcherInfo.client()
      |> WatcherInfoAPI.Api.Stats.stats_get()

    # some sanity check
    %{
      "data" => %{
        "average_block_interval_seconds" => _average_block_interval,
        "block_count" => _block_count
      },
      "service_name" => "watcher_info"
    } = Jason.decode!(response.body)
  end
end
