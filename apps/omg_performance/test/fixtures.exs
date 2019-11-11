# Copyright 2019 OmiseGO Pte Ltd
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

# unfortunately something is wrong with the fixtures loading in `test_helper.exs` and the following needs to be done
Code.require_file("#{__DIR__}/../../omg_child_chain/test/omg_child_chain/integration/fixtures.exs")

defmodule OMG.Performance.Fixtures do
  use ExUnitFixtures.FixtureModule

  use OMG.Eth.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use OMG.Utils.LoggerExt

  deffixture mix_based_watcher(contract) do
    config_file_path = Briefly.create!(extname: ".exs")
    db_path = Briefly.create!(directory: true)

    config_file_path
    |> File.open!([:write])
    |> IO.binwrite("""
    #{Support.DevHelper.create_conf_file(contract)}

    config :omg_db, path: "#{db_path}"
    # this causes the inner test watcher server process to log info. To see these logs adjust test's log level
    config :logger, level: :info
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
        "mix ecto.reset --no-start && mix run --no-start -e ':ok = OMG.DB.init()' --config #{config_file_path} 2>&1",
        exexec_opts_for_mix
      )

    Enum.each(db_out, &log_output("db_init_watcher", &1))

    watcher_mix_cmd = "mix xomg.watcher.start --config #{config_file_path} 2>&1"

    Logger.info("Starting watcher")

    {:ok, watcher_proc, _ref, [{:stream, watcher_out, _stream_server}]} =
      Exexec.run_link(watcher_mix_cmd, exexec_opts_for_mix)

    wait_for_start(watcher_out, "Running OMG.WatcherRPC.Web.Endpoint", 20_000, &log_output("watcher", &1))

    Task.async(fn -> Enum.each(watcher_out, &log_output("watcher", &1)) end)

    on_exit(fn ->
      # NOTE see DevGeth.stop/1 for details
      _ = Process.monitor(watcher_proc)

      :ok =
        case Exexec.stop_and_wait(watcher_proc) do
          :normal ->
            :ok

          :shutdown ->
            :ok

          :noproc ->
            :ok
        end

      File.rm(config_file_path)
      File.rm_rf(db_path)
    end)

    :ok
  end

  # NOTE: we could dry or do sth about this (copied from Support.DevNode), but this might be removed soon altogether
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
end
