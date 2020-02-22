defmodule DrockerStop do
  require Logger

  def stop() do
    exexec_opts_for_mix = [
      stdout: :stream,
      cd: "/opt/Omise/elixir-omg/",
      # group 0 will create a new process group, equal to the OS pid of that process
      group: 0,
      kill_group: true
    ]

    {:ok, docker_compose_down, _ref, [{:stream, _db_out, _stream_server}]} =
      Exexec.run_link(
        "docker-compose down --rmi all -v 2>&1",
        exexec_opts_for_mix
      )

    _ = Process.monitor(docker_compose_down)

    :ok =
      case Exexec.stop_and_wait(docker_compose_down, 30_000) do
        :normal ->
          :ok

        :shutdown ->
          :ok

        :noproc ->
          :ok
      end
  end
end
