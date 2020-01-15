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

  alias FakeServer.Agents.EnvAgent
  alias FakeServer.HTTP.Server
  alias OMG.Eth
  alias OMG.Status.Alert.Alarm
  alias OMG.TestHelper
  alias Support.DevHelper

  @payment_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v1)

  deffixture fee_file(token) do
    # ensuring that the child chain handles the token (esp. fee-wise)

    enc_eth = Eth.Encoding.to_hex(OMG.Eth.RootChain.eth_pseudo_address())

    {:ok, path, file_name} =
      TestHelper.write_fee_file(%{
        @payment_tx_type => %{
          enc_eth => %{
            amount: 0,
            pegged_amount: 1,
            subunit_to_unit: 1_000_000_000_000_000_000,
            pegged_currency: "USD",
            pegged_subunit_to_unit: 100,
            updated_at: DateTime.utc_now()
          },
          Eth.Encoding.to_hex(token) => %{
            amount: 0,
            pegged_amount: 1,
            subunit_to_unit: 1_000_000_000_000_000_000,
            pegged_currency: "USD",
            pegged_subunit_to_unit: 100,
            updated_at: DateTime.utc_now()
          }
        }
      })

    default_file = Application.fetch_env!(:omg_child_chain, :fee_specs_file_name)
    Application.put_env(:omg_child_chain, :fee_specs_file_name, file_name, persistent: true)

    on_exit(fn ->
      :ok = File.rm(path)
      Application.put_env(:omg_child_chain, :fee_specs_file_name, default_file)
    end)

    file_name
  end

  deffixture mix_based_child_chain(contract, fee_file) do
    config_file_path = Briefly.create!(extname: ".exs")
    db_path = Briefly.create!(directory: true)

    config_file_path
    |> File.open!([:write])
    |> IO.binwrite("""
      #{DevHelper.create_conf_file(contract)}

      config :omg_db, path: "#{db_path}"
      # this causes the inner test child chain server process to log info. To see these logs adjust test's log level
      config :logger, level: :info
      config :omg_child_chain, fee_specs_file_name: "#{fee_file}"
    """)
    |> File.close()

    {:ok, config} = File.read(config_file_path)
    Logger.debug(IO.ANSI.format([:blue, :bright, config], true))
    Logger.debug("Starting db_init")

    exexec_opts_for_mix = [
      stdout: :stream,
      cd: Application.fetch_env!(:omg_watcher, :umbrella_root_dir),
      env: %{"MIX_ENV" => to_string(Mix.env())},
      # group 0 will create a new process group, equal to the OS pid of that process
      group: 0,
      kill_group: true
    ]

    {:ok, _db_proc, _ref, [{:stream, db_out, _stream_server}]} =
      Exexec.run_link(
        "mix run --no-start -e ':ok = OMG.DB.init()' --config #{config_file_path} 2>&1",
        exexec_opts_for_mix
      )

    db_out |> Enum.each(&log_output("db_init", &1))

    child_chain_mix_cmd = " mix xomg.child_chain.start --config #{config_file_path} 2>&1"

    Logger.info("Starting child_chain")

    {:ok, child_chain_proc, _ref, [{:stream, child_chain_out, _stream_server}]} =
      Exexec.run_link(child_chain_mix_cmd, exexec_opts_for_mix)

    wait_for_start(child_chain_out, "Running OMG.ChildChainRPC.Web.Endpoint", 20_000, &log_output("child_chain", &1))

    Task.async(fn -> Enum.each(child_chain_out, &log_output("child_chain", &1)) end)

    on_exit(fn ->
      # NOTE see DevGeth.stop/1 for details
      _ = Process.monitor(child_chain_proc)

      :ok =
        case Exexec.stop_and_wait(child_chain_proc) do
          :normal ->
            :ok

          :shutdown ->
            :ok

          :noproc ->
            :ok

          other ->
            _ = Logger.warn("Child chain stopped with an unexpected reason")
            other
        end

      File.rm(config_file_path)
      File.rm_rf(db_path)
    end)

    :ok
  end

  defp wait_for_start(outstream, look_for, timeout, logger_fn) do
    # Monitors the stdout coming out of a process for signal of successful startup
    waiting_task_function = fn ->
      outstream
      |> Stream.map(logger_fn)
      |> Stream.take_while(fn line -> not String.contains?(line, look_for) end)
      |> Enum.to_list()
    end

    waiting_task_function
    |> Task.async()
    |> Task.await(timeout)

    :ok
  end

  defp log_output(prefix, line) do
    Logger.debug("#{prefix}: " <> line)
    line
  end

  deffixture in_beam_watcher(db_initialized, root_chain_contract_config) do
    :ok = db_initialized
    :ok = root_chain_contract_config

    {:ok, started_apps} = Application.ensure_all_started(:omg_db)
    {:ok, started_security_watcher} = Application.ensure_all_started(:omg_watcher)
    {:ok, started_watcher_api} = Application.ensure_all_started(:omg_watcher_rpc)
    wait_for_web()

    on_exit(fn ->
      Application.put_env(:omg_db, :path, nil)

      (started_apps ++ started_security_watcher ++ started_watcher_api)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)
  end

  deffixture test_server do
    {:ok, server_id, port} = Server.run()
    env = FakeServer.Env.new(port)

    EnvAgent.save_env(server_id, env)

    real_addr = Application.fetch_env!(:omg_watcher, :child_chain_url)
    old_client_env = Application.fetch_env!(:omg_watcher, :child_chain_url)
    fake_addr = "http://#{env.ip}:#{env.port}"

    on_exit(fn ->
      Application.put_env(:omg_watcher, :child_chain_url, old_client_env)

      Server.stop(server_id)
      EnvAgent.delete_env(server_id)
    end)

    %{
      real_addr: real_addr,
      fake_addr: fake_addr,
      server_id: server_id
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
