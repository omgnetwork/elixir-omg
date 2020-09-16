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

defmodule OMG.Watcher.Fixtures do
  use ExUnitFixtures.FixtureModule

  use OMG.DB.Fixtures
  use OMG.Eth.Fixtures
  use OMG.Utils.LoggerExt

  alias OMG.Eth
  alias OMG.Status.Alert.Alarm
  alias OMG.TestHelper

  @payment_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v1)

  deffixture fee_file(token) do
    # ensuring that the child chain handles the token (esp. fee-wise)

    enc_eth = Eth.Encoding.to_hex(OMG.Eth.zero_address())

    {:ok, file_path} =
      TestHelper.write_fee_file(%{
        @payment_tx_type => %{
          enc_eth => %{
            amount: 1,
            pegged_amount: 1,
            subunit_to_unit: 1_000_000_000_000_000_000,
            pegged_currency: "USD",
            pegged_subunit_to_unit: 100,
            updated_at: DateTime.utc_now()
          },
          token => %{
            amount: 2,
            pegged_amount: 1,
            subunit_to_unit: 1_000_000_000_000_000_000,
            pegged_currency: "USD",
            pegged_subunit_to_unit: 100,
            updated_at: DateTime.utc_now()
          }
        }
      })

    old_value = Application.fetch_env!(:omg_child_chain, :fee_adapter)

    :ok =
      Application.put_env(
        :omg_child_chain,
        :fee_adapter,
        {OMG.ChildChain.Fees.FileAdapter, opts: [specs_file_path: file_path]},
        persistent: true
      )

    on_exit(fn ->
      :ok = File.rm(file_path)
      :ok = Application.put_env(:omg_child_chain, :fee_adapter, old_value)
    end)

    file_path
  end

  deffixture in_beam_watcher(db_initialized, contract) do
    :ok = db_initialized
    _ = contract

    case System.get_env("DOCKER_GETH") do
      nil ->
        :ok

      _ ->
        # have to hack my way out of this so that we can migrate the watcher integration tests out
        Application.put_env(:omg_watcher, :exit_processor_sla_margin, 40)
    end

    {:ok, started_apps} = Application.ensure_all_started(:omg_db)
    {:ok, started_security_watcher} = Application.ensure_all_started(:omg_watcher)
    {:ok, started_watcher_api} = Application.ensure_all_started(:omg_watcher_rpc)
    wait_for_web()

    on_exit(fn ->
      Application.put_env(:omg_db, :path, nil)

      (started_apps ++ started_security_watcher ++ started_watcher_api)
      |> Enum.reverse()
      |> Enum.map(fn app ->
        :ok = Application.stop(app)
      end)

      Process.sleep(5_000)
    end)
  end

  deffixture test_server do
    server_id = :watcher_test_server
    {:ok, pid} = FakeServer.start(server_id)

    real_addr = Application.fetch_env!(:omg_watcher, :child_chain_url)
    old_client_env = Application.fetch_env!(:omg_watcher, :child_chain_url)
    {:ok, port} = FakeServer.port(server_id)
    fake_addr = "http://localhost:#{port}"

    on_exit(fn ->
      Application.put_env(:omg_watcher, :child_chain_url, old_client_env)

      FakeServer.stop(server_id)
    end)

    %{
      real_addr: real_addr,
      fake_addr: fake_addr,
      server_id: server_id,
      server_pid: pid
    }
  end

  defp wait_for_web(), do: wait_for_web(100)

  defp wait_for_web(counter) do
    case Keyword.has_key?(Alarm.all(), elem(Alarm.main_supervisor_halted(__MODULE__), 0)) do
      true ->
        Process.sleep(100)
        wait_for_web(counter - 1)

      false ->
        :ok
    end
  end
end
